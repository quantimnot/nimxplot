import std/[sugar, strutils]
import nimx/[
  context,
  control,
  event,
  font
 ]

type ModelXY*[T] = seq[tuple[x: T, y: T]]
  ## y=f(x) discrete data model

type ModelXYColor*[T] = seq[tuple[x: T, y: T, color: Color]]
  ## t=f(x) discrete data model with colored dots

# series view
# 0 1 2 3 4  <- this is the complete data
#  |1 2 3|   <- this is data subsection that is being rendered
#
# Each point has a:
#   - min width of a pixel
#   - max width of the plot content width
#
type
  SeriesView = tuple
    series: Slice[int]
    view: Slice[int]

type
  SeriesBounds* = tuple
    minx, maxx, miny, maxy: float64

type Plot* = ref object of Control
  title*: string
  labelX*: string
  labelY*: string
  boundary*: float32
  gridstep*: float32
  gridLineWidth*: float32
  gridColor*: Color
  font*: Font
  textColor*: Color
  pointSize*: int
  highlightedPoint*: int
  highlightetPointSize*: int
  highlightedPointLabelYOffset*: float32
  items*: iterator(): (float, float) {.closure.}
  model*: ModelXYColor[float64]
  scale: tuple[x, y: float64]
  modelBounds: SeriesBounds
  poly: seq[Coord]


method init(model: Plot, r: Rect) =
  procCall model.Control.init(r)
  model.backgroundColor = whiteColor()
  model.boundary = 30.0
  model.gridstep = 15.0
  model.gridLineWidth = 1.0
  model.gridColor = newGrayColor(0.7)
  model.font = systemFont()
  model.textColor = blackColor()
  model.pointSize = 4
  model.highlightedPoint = -1
  model.highlightetPointSize = 4
  model.highlightedPointLabelYOffset = 20.0


type LinePlot* = ref object of Plot
  ## Plotting widgets that implements rendering of "y=f(x)" function.
  lineColor*: Color
  drawMedian*: bool
  lineWidth*: float


method init(model: LinePlot, r: Rect) =
  procCall model.Plot.init(r)
  model.lineWidth = 2.0
  model.drawMedian = false
  model.lineColor = blackColor()


proc newPlotXY*(r: Rect, model: ModelXYColor[float64]): LinePlot =
  result.new()
  result.model = model
  result.init(r)


type PointPlot* = ref object of LinePlot
  pointColor*: Color


method init(model: PointPlot, r: Rect) =
  procCall model.LinePlot.init(r)
  model.pointColor = blackColor()


proc modelBounds*(model: Plot): SeriesBounds =
  model.modelBounds


proc updateModel(model: Plot) =
  model.modelBounds.minx = float.high
  model.modelBounds.maxx = float.low
  model.modelBounds.miny = float.high
  model.modelBounds.maxy = float.low

  for point in model.model.items():
    model.modelBounds.minx = min(point.x, model.modelBounds.minx)
    model.modelBounds.miny = min(point.y, model.modelBounds.miny)
    model.modelBounds.maxx = max(point.x, model.modelBounds.maxx)
    model.modelBounds.maxy = max(point.y, model.modelBounds.maxy)

  model.scale = (
    (model.bounds.width - model.boundary * 2) / (model.modelBounds.maxx - model.modelBounds.minx),
    (model.bounds.height - model.boundary * 2) / (model.modelBounds.maxy - model.modelBounds.miny)
  )

  model.poly.reset
  for point in model.model.items():
    model.poly.add(  model.boundary + (Coord(point.x.float32) - model.modelBounds.minx) * model.scale.x)
    model.poly.add(-(model.boundary + (Coord(point.y.float32) - model.modelBounds.miny) * model.scale.y) + Coord(model.bounds.height))


proc drawGrid(gfx: GraphicsContext, model: Plot, r: Rect) =
  ## Draw a grid.
  gfx.strokeColor = model.gridColor
  gfx.strokeWidth = model.gridLineWidth

  model.gridstep = model.model.len.float

  for i in 0..model.gridstep.int:
    let
      pStart = newPoint(model.boundary, r.size.height - model.boundary - i.float32 * (r.size.height - model.boundary * 2) / model.gridstep)
      pEnd = newPoint(r.size.width - model.boundary, r.size.height - model.boundary - i.float32 * (r.size.height - model.boundary * 2) / model.gridstep)
    gfx.drawLine(pStart, pEnd)

  for i in 0..model.gridstep.int:
    let
      pStart = newPoint(model.boundary + i.float32 * (r.size.width - model.boundary * 2) / model.gridstep, model.boundary)
      pEnd = newPoint(model.boundary + i.float32 * (r.size.width - model.boundary * 2) / model.gridstep, r.size.height - model.boundary)
    gfx.drawLine(pStart, pEnd)


proc drawTitle(gfx: GraphicsContext, model: Plot, r: Rect) =
  ## Draw title
  var pt = centerInRect(sizeOfString(model.font, model.title), newRect(0.0, 0.0, r.size.width, model.boundary))
  gfx.fillColor = model.textColor
  gfx.drawText(model.font, pt, model.title)

  for i in 0..model.gridstep.int:
    let pt = newPoint(2, r.size.height - model.boundary - i.float32 * (r.size.height - model.boundary * 2) / model.gridstep)
    let stepValue = (model.modelBounds.maxy - model.modelBounds.miny) / model.gridstep * i.float32 + model.modelBounds.miny
    gfx.drawText(model.font, pt, $stepValue.int)

  for i in 0..model.gridstep.int:
    pt = newPoint(model.boundary + i.float32 * (r.size.width - model.boundary * 2) / model.gridstep, r.size.height - model.boundary)
    let stepValue = (model.modelBounds.maxx - model.modelBounds.minx) / model.gridstep * i.float32 + model.modelBounds.minx
    gfx.drawText(model.font, pt, $stepValue.int)


proc drawAxesLabels(gfx: GraphicsContext, model: Plot, r: Rect) =
  ## Draw axes labels
  var pt = newPoint(model.boundary / 2, model.boundary / 2)
  gfx.fillColor = model.textColor
  gfx.drawText(model.font, pt, model.labelY)

  if model.highlightedPoint > -1:
    let index: int = (model.highlightedPoint.float).int
    let x = model.model[(index / 2).int].x
    let y = model.model[(index / 2).int].y
    gfx.drawText(model.font, newPoint(model.poly[index], model.poly[index+1] - model.highlightedPointLabelYOffset), "($#, $#)" % [$x, $y])

  pt = newPoint(r.size.width - model.boundary * 2, r.size.height - model.boundary / 1.5)
  gfx.drawText(model.font, pt, model.labelX)


proc plotLine(gfx: GraphicsContext, model: LinePlot, r: Rect) =
  ## Draw graph
  gfx.fillColor = blackColor()
  gfx.strokeColor = model.lineColor
  gfx.strokeWidth = model.lineWidth

  if model.model.len() > 0:
    if model.drawMedian:
      gfx.strokeColor = newColor(0.0, 1.0, 0.0)
      gfx.drawLine(newPoint(model.poly[0], model.poly[1]), newPoint(model.poly[model.poly.len() - 2], model.poly[model.poly.len() - 1]))

    gfx.strokeColor = model.lineColor
    for i in countup(0, model.poly.len()-3, 2):
      gfx.drawLine(
        newPoint(model.poly[i], model.poly[i+1]),
        newPoint(model.poly[i+2], model.poly[i+3])
      )


proc plotPoints(gfx: GraphicsContext, model: PointPlot, r: Rect) =
  gfx.fillColor = model.pointColor
  gfx.strokeColor = model.pointColor

  template rect(n0, n, size): untyped =
    newRect(model.poly[n0] - size.Coord, model.poly[n] - size.Coord, size.Coord * 2, size.Coord * 2)

  if model.model.len() > 0:
    for i in countup(0, model.poly.len()-3, 2):
      gfx.strokeColor = model.model[(i/2).int].color
      gfx.fillColor = gfx.strokeColor

      if model.pointSize > 0:
        if model.highlightedPoint != -1:
          if i == model.highlightedPoint or i == model.highlightedPoint + 1:
            gfx.drawEllipseInRect(rect(i, i+1, model.highlightetPointSize))
        gfx.drawEllipseInRect(rect(i, i+1, model.pointSize))
    if model.pointSize > 0:
      gfx.drawEllipseInRect(rect(^2, ^1, model.pointSize))


method draw*(model: Plot, r: Rect) =
  let gfx = currentContext()
  procCall model.View.draw(r)
  updateModel(model)
  drawGrid(gfx, model, r)
  drawTitle(gfx, model, r)
  drawAxesLabels(gfx, model, r)


method draw*(model: LinePlot, r: Rect) =
  let gfx = currentContext()
  procCall model.Plot.draw(r)
  plotLine(gfx, model, r)


method draw*(model: PointPlot, r: Rect) =
  let gfx = currentContext()
  procCall model.LinePlot.draw(r)
  plotPoints(gfx, model, r)


template insideBounds(point: Point, model: Plot) =
  if point.x < model.boundary or point.x > model.bounds.width - model.boundary:
    return true
  if point.y < model.boundary or point.y > model.bounds.height - model.boundary:
    return true


method onMouseDown(model: Plot, e: var Event): bool {.base.} =
  let pos = e.localPosition
  insideBounds(pos, model)

  let xpart = ((pos.x - model.boundary) / (model.bounds.width - 2 * model.boundary))
  let ypart = (pos.y / (model.bounds.height - 2 * model.boundary))

  let hp = newPoint(
    xpart * (model.modelBounds.maxx - model.modelBounds.minx),
    ypart * (model.modelBounds.maxy - model.modelBounds.miny)
  )

  for i, v in model.model.pairs():
    if v.x > hp.x:
      if hp.x - model.model[i-1].x < model.model[i].x - hp.x:
        model.highlightedPoint = (i - 1) * 2
      else:
        model.highlightedPoint = i * 2
      break

  model.setNeedsDisplay()
  return true


method onMouseUp(model: Plot, e: var Event): bool {.base.} =
  model.highlightedPoint = -1
  model.setNeedsDisplay()
  return true


method onTouchEv*(model: Plot, e: var Event): bool =
  case e.buttonState
  of bsDown: onMouseDown(model, e)
  of bsUp: onMouseUp(model, e)
  of bsUnknown: false


iterator xy(): (float, float) {.closure.} =
  for x in 0..1000:
    yield (x.float, (x + 2).float)
  

# nim r --threads:on nimxplot
when isMainModule:
  import nimx/[window, layout]
  # import nimxplot

  runApplication:
    newFullscreenWindow().makeLayout:
      - PointPlot:
        leading == super + 10
        trailing == super - 10
        top == super + 10
        bottom == super - 10
        title: "Dependency of Y from X"
        labelY: "Y"
        labelX: "X"
        lineWidth: 1
        pointSize: 1
        items: xy
        # xWindowMaxSize: 2
        model: @[
          # (x: 0.0, y: 0.0, color: newColor(0, 0, 0)),
          (x: 10.0, y: 10.0, color: newColor(1, 0, 0)),
          (x: 20.0, y: 10.0, color: newColor(0, 1, 0)),
          (x: 60.0, y: 300.0, color: newColor(0, 0, 1)),
          # (x: 100.0, y: 200.0, color: newColor(1, 1, 0))
        ]
