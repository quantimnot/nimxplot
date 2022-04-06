import
  std/[sugar, strutils, strformat, options],
  pkg/nimx/[
    context,
    control,
    event,
    font
  ]

# type ModelXY*[T] = seq[Point]
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

type
  # Plot*[Color; Font; Coord] = ref object of RootObj
  #   title*: string
  #   labelX*: string
  #   labelY*: string
  #   boundary*: float32
  #   gridstep*: float32
  #   gridLineWidth*: float32
  #   gridColor*: Color
  #   font*: Font
  #   textColor*: Color
  #   pointSize*: int
  #   highlightedPoint*: int
  #   highlightetPointSize*: int
  #   highlightedPointLabelYOffset*: float32
  #   numPointsToPlot*: int
  #   maxPoints*: int
  #   dataRange*: Slice[int]
  #   model*: ModelXYColor[float64]
  #   scale: tuple[x, y: float64]
  #   modelBounds: SeriesBounds
  #   poly: seq[Coord]

  PlotControl* = ref object of Control
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
    closestPointIndex*: Option[int]
    highlightClosest*: bool
    highlightedPointIndex*: Option[int]
    highlightedPointScaler*: float
    highlightedPointLabelYOffset*: float32
    numPointsToPlot*: int
    maxPoints*: int
    dataRange*: Slice[int]
    model*: seq[Point]
    scale: tuple[x, y: float64]
    modelBounds: SeriesBounds
    drawCrossHair*: bool
    crossHairColor*: Color
    hoverPoint: Option[Point]


# func newPlot*[Color, Font, Coord](): Plot[Color, Font, Coord] =
#   Plot[Color, Font, Coord](
#     backgroundColor: whiteColor(),
#     boundary: 30.0,
#     gridstep: 15.0,
#     gridLineWidth: 1.0,
#     gridColor: newGrayColor(0.7),
#     font: systemFont(),
#     textColor: blackColor(),
#     pointSize: 4,
#     highlightedPoint: -1,
#     highlightetPointSize: 4,
#     highlightedPointLabelYOffset: 20.0
#   )


template rect(point, size): untyped =
  let dim = size * 2
  newRect(point.x - size, point.y - size, dim, dim)


method init(model: PlotControl, r: Rect) =
  procCall model.Control.init(r)
  model.trackMouseOver(true)
  # model.plot = newPlot()
  model.backgroundColor = whiteColor()
  model.boundary = 30.0
  model.gridstep = 15.0
  model.gridLineWidth = 1.0
  model.gridColor = newGrayColor(0.7)
  model.font = systemFont()
  model.textColor = blackColor()
  model.pointSize = 4
  model.crossHairColor = blackColor()
  model.highlightedPointScaler = 1.25
  model.highlightedPointLabelYOffset = 20.0


type LinePlotControl* = ref object of PlotControl
  ## Plotting widgets that implements rendering of "y=f(x)" function.
  lineColor*: Color
  drawMedian*: bool
  lineWidth*: float


method init(model: LinePlotControl, r: Rect) =
  procCall model.PlotControl.init(r)
  model.lineWidth = 2.0
  model.drawMedian = false
  model.lineColor = blackColor()


# proc newPlotXY*(r: Rect, model: ModelXYColor[float64]): LinePlotControl =
#   result.new()
#   result.model = model
#   result.init(r)


type PointPlotControl* = ref object of LinePlotControl
  pointColor*: Color


method init(model: PointPlotControl, r: Rect) =
  procCall model.LinePlotControl.init(r)
  model.pointColor = blackColor()


proc modelBounds*(model: PointPlotControl): SeriesBounds =
  model.modelBounds


func translateAndScalePoint(model: PlotControl, point: Point): Point =
  newPoint(
    model.boundary + (Coord(point.x.float32) - model.modelBounds.minx) * model.scale.x,
    -(model.boundary + (Coord(point.y.float32) - model.modelBounds.miny) * model.scale.y) + Coord(model.bounds.height)
  )


proc updateModel(model: PlotControl, r: Rect) =
  model.modelBounds.minx = float.high
  model.modelBounds.maxx = float.low
  model.modelBounds.miny = float.high
  model.modelBounds.maxy = float.low

  model.maxPoints = (r.size.width - model.boundary * 2).int div model.pointSize

  if model.maxPoints > 0:
    if model.model.len <= model.maxPoints:
      model.dataRange = 0..model.model.len-1
    else:
      model.dataRange = (model.model.len-model.maxPoints)..model.model.len-1

    for point in model.model[model.dataRange].items():
      model.modelBounds.minx = min(point.x, model.modelBounds.minx)
      model.modelBounds.miny = min(point.y, model.modelBounds.miny)
      model.modelBounds.maxx = max(point.x, model.modelBounds.maxx)
      model.modelBounds.maxy = max(point.y, model.modelBounds.maxy)

    model.scale = (
      (model.bounds.width - model.boundary * 2) / (model.modelBounds.maxx - model.modelBounds.minx),
      (model.bounds.height - model.boundary * 2) / (model.modelBounds.maxy - model.modelBounds.miny)
    )


proc drawGrid(gfx: GraphicsContext, model: PlotControl, r: Rect) =
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


proc drawTitle(gfx: GraphicsContext, model: PlotControl, r: Rect) =
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


proc drawCrossHair(gfx: GraphicsContext, model: PlotControl, r: Rect) =
  if model.drawCrossHair and model.hoverPoint.isSome:
    gfx.fillColor = model.crossHairColor
    gfx.strokeColor = model.crossHairColor
    gfx.drawEllipseInRect(rect(model.hoverPoint.get, 4.Coord))


proc drawAxesLabels(gfx: GraphicsContext, model: PlotControl, r: Rect) =
  ## Draw axes labels
  var pt = newPoint(model.boundary / 2, model.boundary / 2)
  gfx.fillColor = model.textColor
  gfx.drawText(model.font, pt, model.labelY)

  if model.highlightedPointIndex.isSome:
    let x = model.model[(model.highlightedPointIndex.get / 2).int].x
    let y = model.model[(model.highlightedPointIndex.get / 2).int].y
    let highlightedPoint = model.model[model.highlightedPointIndex.get]
    var labelOrigin = translateAndScalePoint(model, highlightedPoint)
    labelOrigin.y -= model.highlightedPointLabelYOffset
    gfx.drawText(model.font, labelOrigin, &"({highlightedPoint.x}, {highlightedPoint.y})")

  pt = newPoint(r.size.width - model.boundary * 2, r.size.height - model.boundary / 1.5)
  gfx.drawText(model.font, pt, model.labelX)


iterator lines(model: PlotControl): (Point, Point) =
  var i = 0
  while i+1 < model.model.len:
    yield (
      translateAndScalePoint(model, model.model[i]),
      translateAndScalePoint(model, model.model[i+1])
    )
    i.inc


proc plotLine(gfx: GraphicsContext, model: LinePlotControl, r: Rect) =
  gfx.strokeWidth = model.lineWidth
  gfx.strokeColor = model.lineColor
  for (p0, p1) in model.lines():
    gfx.drawLine(p0, p1)


proc plotPoints(gfx: GraphicsContext, model: PointPlotControl, r: Rect) =
  gfx.fillColor = model.pointColor
  gfx.strokeColor = model.pointColor
  for idx, point in model.model.pairs():
    if model.highlightClosest and model.closestPointIndex.get(-1) == idx:
      gfx.drawEllipseInRect(rect(translateAndScalePoint(model, point), model.highlightedPointScaler.Coord * model.pointSize.Coord))
    else:
      gfx.drawEllipseInRect(rect(translateAndScalePoint(model, point), model.pointSize.Coord))


method draw*(model: PlotControl, r: Rect) =
  let gfx = currentContext()
  procCall model.View.draw(r)
  updateModel(model, r)
  drawGrid(gfx, model, r)
  drawTitle(gfx, model, r)
  drawAxesLabels(gfx, model, r)


proc drawOverlays(gfx: GraphicsContext, model: PlotControl, r: Rect) =
  drawCrossHair(gfx, model, r)


method draw*(model: LinePlotControl, r: Rect) =
  let gfx = currentContext()
  procCall model.PlotControl.draw(r)
  plotLine(gfx, model, r)
  drawOverlays(gfx, model, r)


method draw*(model: PointPlotControl, r: Rect) =
  let gfx = currentContext()
  procCall model.PlotControl.draw(r)
  plotLine(gfx, model, r)
  plotPoints(gfx, model, r)
  drawOverlays(gfx, model, r)


func insideBounds(model: PlotControl, point: Point): bool =
  if point.x < model.boundary or point.x > model.bounds.width - model.boundary or
     point.y < model.boundary or point.y > model.bounds.height - model.boundary:
    return false
  true


method onMouseDown(model: PlotControl, e: var Event): bool {.base.} =
  let pos = e.localPosition
  if insideBounds(model, pos):
    let xpart = ((pos.x - model.boundary) / (model.bounds.width - 2 * model.boundary))
    let ypart = ((pos.y - model.boundary) / (model.bounds.height - 2 * model.boundary))

    let touchPoint = newPoint(
      (xpart * (model.modelBounds.maxx - model.modelBounds.minx)) + model.modelBounds.minx,
      (ypart * (model.modelBounds.maxy - model.modelBounds.miny)) + model.modelBounds.miny
    )

    for idx, point in model.model.pairs():
      if point.x > touchPoint.x:
        if touchPoint.x - model.model[idx-1].x < model.model[idx].x - touchPoint.x:
          model.closestPointIndex = some idx-1
        else:
          model.closestPointIndex = some idx
        model.highlightedPointIndex = model.closestPointIndex
        break

    model.setNeedsDisplay()
  return true


method onMouseUp(model: PlotControl, e: var Event): bool {.base.} =
  model.closestPointIndex.reset
  model.highlightedPointIndex.reset
  model.setNeedsDisplay()
  return true


iterator xy(): (float, float64) {.closure.} =
  for x in 0..1000:
    yield (x.float, (x + 2).float)


when declared View:
  # method onMouseIn*(model: PlotControl, e: var Event) =
  #   echo "onMouseIn"

  method onMouseOver*(model: PlotControl, e: var Event) =
    if insideBounds(model, e.localPosition):
      model.hoverPoint = some e.localPosition
    else:
      model.hoverPoint.reset
    model.setNeedsDisplay()

  # method onMouseOut*(model: PlotControl, e: var Event) =
  #   model.hoverPoint.reset

  method onTouchEv*(model: PlotControl, e: var Event): bool =
    case e.buttonState
    of bsDown: onMouseDown(model, e)
    of bsUp: onMouseUp(model, e)
    of bsUnknown: false



# nim r --threads:on nimxplot
when isMainModule:
  import nimx/[window, layout]
  # import nimxplot

  runApplication:
    newFullscreenWindow().makeLayout:
      - PointPlotControl:
        title: "Dependency of Y from X"
        labelY: "Y"
        labelX: "X"
        lineWidth: 1
        pointSize: 4
        drawCrossHair: true
        highlightClosest: true
        model: @[
          # (x: 0.0, y: 0.0, color: newColor(0, 0, 0)),
          (x: Coord(10.0), y: Coord(10.0)),
          (x: Coord(20.0), y: Coord(10.0)),
          (x: Coord(60.0), y: Coord(300.0)),
          # (x: 100.0, y: 200.0, color: newColor(1, 1, 0))
        ]
        leading == super
        trailing == super
        top == super
        bottom == super

  # runApplication:
  #   newFullscreenWindow().makeLayout:
  #     - PointPlotControl:
  #       plot: newPlot(
  #         title: "Dependency of Y from X"
  #         labelY: "Y"
  #         labelX: "X"
  #         lineWidth: 1
  #         pointSize: 10
  #         model: @[
  #           # (x: 0.0, y: 0.0, color: newColor(0, 0, 0)),
  #           (x: 10.0, y: 10.0, color: newColor(1, 0, 0)),
  #           (x: 20.0, y: 10.0, color: newColor(0, 1, 0)),
  #           (x: 60.0, y: 300.0, color: newColor(0, 0, 1)),
  #           # (x: 100.0, y: 200.0, color: newColor(1, 1, 0))
  #         ]
  #       )
  #       leading == super + 10
  #       trailing == super - 10
  #       top == super + 10
  #       bottom == super - 10
