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
  Plot* = ref object
    title*: string
    xTitle*: string
    yTitle*: string
    boundaries*: tuple[top, bottom, left, right: Natural]
    borderWidth*: Natural
    gridLineWidth*: float32
    minMarginWidth*: int
    minMarkerWidth*: int
    maxMarkerWidthScaler*: float
    backgroundColor*: Color
    borderColor*: Color
    gridColor*: Color
    textColor*: Color
    font*: Font
    model*: seq[Point]
    # calculated state
    plotRect: Rect
    plotContentRect: Rect
    maxPlottablePoints: int
    numPointsToPlot: int
    marginWidth: int
    marginWidthRemainder: int
    gridstep: float32
    dataRange: Slice[int]
    titleSize: Size
    xTitleSize: Size
    yTitleSize: Size
    titlePos: Point
    xTitlePos: Point
    yTitlePos: Point

  PlotControl* = ref object of Control
    plot*: Plot
    crossHairColor*: Color
    markerSize*: int
    closestPointIndex*: Option[int]
    highlightClosest*: bool
    highlightedPointIndex*: Option[int]
    highlightedPointScaler*: float
    highlightedPointyTitleOffset*: float32
    zoom*: float
    dataRange*: Slice[int]
    scale: tuple[x, y: float64]
    modelBounds: SeriesBounds
    drawCrossHair*: bool
    hoverPoint: Option[Point]
    scrollOffset: Option[Point]


template rect(point, size): untyped =
  let dim = size * 2
  newRect(point.x - size, point.y - size, dim, dim)


func initBoundary(top, bottom, left, right: int): tuple[top, bottom, left, right: Natural] =
  (Natural(top), Natural(bottom), Natural(left), Natural(right))


proc newPlot(
    title: string,
    xTitle: string,
    yTitle: string,
    boundaries = initBoundary(30, 30, 30, 1),
    borderWidth = 1,
    minMarginWidth = 0,
    minMarkerWidth = 1,
    maxMarkerWidthScaler = 2.0,
    backgroundColor = newGrayColor(0.5),
    borderColor = blackColor(),
    gridColor = newGrayColor(0.7),
    font = systemFont(),
    textColor = blackColor(),
    model: seq[Point]
    ): Plot =
  Plot(
    title: title,
    xTitle: xTitle,
    yTitle: yTitle,
    boundaries: boundaries,
    borderWidth: borderWidth,
    minMarginWidth: minMarginWidth,
    minMarkerWidth: minMarkerWidth,
    maxMarkerWidthScaler: maxMarkerWidthScaler,
    backgroundColor: backgroundColor,
    borderColor: borderColor,
    gridColor: gridColor,
    textColor: textColor,
    font: font,
    model: model
  )


method init(model: PlotControl, r: Rect) =
  procCall model.Control.init(r)
  model.trackMouseOver(true)
  model.backgroundColor = whiteColor()
  model.markerSize = 4
  model.crossHairColor = blackColor()
  model.highlightedPointScaler = 1.25
  model.highlightedPointyTitleOffset = 20.0


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


# func translateAndScalePoint(model: PlotControl, point: Point): Point =
#   newPoint(
#     model.boundary + (Coord(point.x.float32) - model.modelBounds.minx) * model.scale.x,
#     -(model.boundary + (Coord(point.y.float32) - model.modelBounds.miny) * model.scale.y) + Coord(model.bounds.height)
#   )


# proc zoom(model: PlotControl, r: Rect) =
#   # The number of data points plotted for full zoom is the chosen min marker size plus min margin between markers.
#   # | * * * | points=3 margins=4 (points + 1)
#   let plotContentWidth = (r.size.width - model.boundary * 2 - model.borderWidth.float * 2).int
#   let maxPlottablePoints = plotContentWidth div model.markerSize
#   let totalMarginSpace = model.numPointsToPlot.get(0) + 1


# proc updateModel(model: PlotControl, r: Rect) =
#   model.modelBounds.minx = float.high
#   model.modelBounds.maxx = float.low
#   model.modelBounds.miny = float.high
#   model.modelBounds.maxy = float.low

#     echo model.dataRange
#     echo model.model[model.dataRange]

#     for point in model.model[model.dataRange].items():
#       model.modelBounds.minx = min(point.x, model.modelBounds.minx)
#       model.modelBounds.miny = min(point.y, model.modelBounds.miny)
#       model.modelBounds.maxx = max(point.x, model.modelBounds.maxx)
#       model.modelBounds.maxy = max(point.y, model.modelBounds.maxy)

#     model.scale = (
#       (model.bounds.width - model.boundary * 2) / (model.modelBounds.maxx - model.modelBounds.minx),
#       (model.bounds.height - model.boundary * 2) / (model.modelBounds.maxy - model.modelBounds.miny)
#     )


# template drawVerticalLine(gfx: GraphicsContext, model: PlotControl, r: Rect, index: int) =


proc drawBorder(gfx: GraphicsContext, model: PlotControl) =
  gfx.strokeColor = model.plot.borderColor
  gfx.fillColor = model.plot.backgroundColor
  gfx.strokeWidth = model.plot.borderWidth.Coord
  gfx.drawRect(model.plot.plotRect)


# proc drawGrid(gfx: GraphicsContext, model: PlotControl, r: Rect) =
#   ## Draw a grid.
#   gfx.strokeColor = model.gridColor
#   gfx.strokeWidth = 1.0

#   model.gridstep = (model.model[model.dataRange].len - 1).float

#   for i in 0..model.gridstep.int:
#     let
#       pStart = newPoint(model.boundary, r.size.height - model.boundary - i.float32 * (r.size.height - model.boundary * 2) / model.gridstep)
#       pEnd = newPoint(r.size.width - model.boundary, r.size.height - model.boundary - i.float32 * (r.size.height - model.boundary * 2) / model.gridstep)
#     gfx.drawLine(pStart, pEnd)

#   for i in 0..model.gridstep.int:
#     let
#       pStart = newPoint(model.boundary + i.float32 * (r.size.width - model.boundary * 2) / model.gridstep, model.boundary)
#       pEnd = newPoint(model.boundary + i.float32 * (r.size.width - model.boundary * 2) / model.gridstep, r.size.height - model.boundary)
#     gfx.drawLine(pStart, pEnd)


# template drawAxisTick(gfx: GraphicsContext, model: PlotControl, tickIndex: int) =


proc drawTitles(gfx: GraphicsContext, model: PlotControl) =
  gfx.fillColor = model.plot.textColor
  echo &"drawTitles: titlePos {model.plot.titlePos}"
  # plot title
  if model.plot.title.len > 0:
    gfx.drawText(model.plot.font, model.plot.titlePos, model.plot.title)
    echo &"drawTitles: titlePos {model.plot.titlePos}"
  # x axis title
  if model.plot.xTitle.len > 0:
    gfx.drawText(model.plot.font, model.plot.xTitlePos, model.plot.xTitle)
  # # y axis title
  if model.plot.yTitle.len > 0:
    gfx.drawText(model.plot.font, model.plot.yTitlePos, model.plot.yTitle)


proc drawCrossHair(gfx: GraphicsContext, model: PlotControl) =
  if model.drawCrossHair and model.hoverPoint.isSome:
    gfx.fillColor = model.crossHairColor
    gfx.strokeColor = model.crossHairColor
    gfx.drawEllipseInRect(rect(model.hoverPoint.get, 4.Coord))


# proc drawAxesLabels(gfx: GraphicsContext, model: PlotControl) =
#   var pt: Point
#   gfx.fillColor = model.textColor

#   # x axis labels
#   for i in 0..model.gridstep.int:
#     pt = newPoint(model.boundary + i.float32 * (model.frame.size.width - model.boundary * 2) / model.gridstep, model.frame.size.height - model.boundary)
#     let stepValue = (model.modelBounds.maxx - model.modelBounds.minx) / model.gridstep * i.float32 + model.modelBounds.minx
#     echo stepValue
#     gfx.drawText(model.font, pt, $stepValue.int)

#   # y axis labels
#   for i in 0..model.gridstep.int:
#     pt = newPoint(2, model.frame.size.height - model.boundary - i.float32 * (model.frame.size.height - model.boundary * 2) / model.gridstep)
#     let stepValue = (model.modelBounds.maxy - model.modelBounds.miny) / model.gridstep * i.float32 + model.modelBounds.miny
#     gfx.drawText(model.font, pt, $stepValue.int)

#   if model.highlightedPointIndex.isSome:
#     let highlightedPoint = model.model[model.dataRange][model.highlightedPointIndex.get]
#     var labelOrigin = translateAndScalePoint(model, highlightedPoint)
#     labelOrigin.y -= model.highlightedPointyTitleOffset
#     gfx.drawText(model.font, labelOrigin, &"({highlightedPoint.x}, {highlightedPoint.y})")


# iterator nextPointRect(model: PlotControl): Rect =


proc drawFakeBars(gfx: GraphicsContext, model: PlotControl) =
  ## This is only for development and debugging.
  gfx.strokeColor = whiteColor()
  gfx.fillColor = whiteColor()
  if model.plot.numPointsToPlot > 0:
    for i in 0..model.plot.numPointsToPlot-1:
      gfx.drawRect(newRect(
        model.plot.plotContentRect.origin.x + (model.plot.marginWidth + model.plot.minMarkerWidth * i + model.plot.marginWidth * i).Coord,
        model.plot.plotContentRect.origin.y,
        model.plot.minMarkerWidth.Coord,
        model.plot.plotContentRect.size.height
      ))


method draw*(model: PlotControl, r: Rect) =
  let gfx = currentContext()
  procCall model.View.draw(r)
  # updateModel(model, r)
  drawBorder(gfx, model)
  drawTitles(gfx, model)
  drawFakeBars(gfx, model)
  # drawGrid(gfx, model, r)
  # drawAxesLabels(gfx, model, r)


# iterator lines(model: PlotControl): (Point, Point) =
#   var i = 0
#   while i+1 < model.model[model.dataRange].len:
#     yield (
#       translateAndScalePoint(model, model.model[model.dataRange][i]),
#       translateAndScalePoint(model, model.model[model.dataRange][i+1])
#     )
#     i.inc


# proc plotLine(gfx: GraphicsContext, model: LinePlotControl, r: Rect) =
#   gfx.strokeWidth = model.lineWidth
#   gfx.strokeColor = model.lineColor
#   for (p0, p1) in model.lines():
#     gfx.drawLine(p0, p1)


# proc plotPoints(gfx: GraphicsContext, model: PointPlotControl, r: Rect) =
#   gfx.fillColor = model.pointColor
#   gfx.strokeColor = model.pointColor
#   for idx, point in model.model[model.dataRange].pairs():
#     if model.highlightClosest and model.closestPointIndex.get(-1) == idx:
#       gfx.drawEllipseInRect(rect(translateAndScalePoint(model, point), model.highlightedPointScaler.Coord * model.markerSize.Coord))
#     else:
#       gfx.drawEllipseInRect(rect(translateAndScalePoint(model, point), model.markerSize.Coord))


# proc drawOverlays(gfx: GraphicsContext, model: PlotControl, r: Rect) =
#   drawCrossHair(gfx, model, r)


# method draw*(model: LinePlotControl, r: Rect) =
#   let gfx = currentContext()
#   procCall model.PlotControl.draw(r)
#   plotLine(gfx, model, r)
#   drawOverlays(gfx, model, r)


# method draw*(model: PointPlotControl, r: Rect) =
#   let gfx = currentContext()
#   procCall model.PlotControl.draw(r)
#   plotLine(gfx, model, r)
#   plotPoints(gfx, model, r)
#   drawOverlays(gfx, model, r)


# func insideBounds(model: PlotControl, point: Point): bool =
#   if point.x < model.boundary or point.x > model.bounds.width - model.boundary or
#      point.y < model.boundary or point.y > model.bounds.height - model.boundary:
#     return false
#   true


# method onMouseDown(model: PlotControl, e: var Event): bool {.base.} =
#   let pos = e.localPosition
#   if insideBounds(model, pos):
#     let xpart = ((pos.x - model.boundary) / (model.bounds.width - 2 * model.boundary))
#     let ypart = ((pos.y - model.boundary) / (model.bounds.height - 2 * model.boundary))

#     let touchPoint = newPoint(
#       (xpart * (model.modelBounds.maxx - model.modelBounds.minx)) + model.modelBounds.minx,
#       (ypart * (model.modelBounds.maxy - model.modelBounds.miny)) + model.modelBounds.miny
#     )

#     for idx, point in model.model[model.dataRange].pairs():
#       if point.x > touchPoint.x:
#         if touchPoint.x - model.model[model.dataRange][idx-1].x < model.model[model.dataRange][idx].x - touchPoint.x:
#           model.closestPointIndex = some idx-1
#         else:
#           model.closestPointIndex = some idx
#         model.highlightedPointIndex = model.closestPointIndex
#         break

#     model.setNeedsDisplay()
#   return true


# method onMouseUp(model: PlotControl, e: var Event): bool {.base.} =
#   model.closestPointIndex.reset
#   model.highlightedPointIndex.reset
#   model.setNeedsDisplay()
#   return true


# iterator xy(): (float, float64) {.closure.} =
#   for x in 0..1000:
#     yield (x.float, (x + 2).float)


when declared View:
  method updateLayout*(model: PlotControl) =
    # procCall model.Control.updateLayout()
    # let bounds = model.bounds.size # TODO: bounds vs frame???
    model.plot.plotRect = newRect(
      model.plot.boundaries.left.Coord,
      model.plot.boundaries.top.Coord,
      model.frame.size.width - (model.plot.boundaries.left + model.plot.boundaries.right).Coord,
      model.frame.size.height - (model.plot.boundaries.top + model.plot.boundaries.bottom).Coord)
    model.plot.plotContentRect = newRect(
      model.plot.plotRect.origin.x + model.plot.borderWidth.Coord,
      model.plot.plotRect.origin.y + model.plot.borderWidth.Coord,
      (model.plot.plotRect.size.width - model.plot.borderWidth.float * 2).Coord,
      (model.plot.plotRect.size.height - model.plot.borderWidth.float * 2).Coord
    )
    model.plot.maxPlottablePoints = model.plot.plotContentRect.size.width.int div model.plot.minMarkerWidth
    model.plot.numPointsToPlot = min((model.zoom * model.plot.maxPlottablePoints.float).int, model.plot.model.len)
    let totalMarginWidth = (model.plot.plotContentRect.size.width.int - (model.plot.numPointsToPlot * model.plot.minMarkerWidth))
    model.plot.marginWidth = totalMarginWidth div (model.plot.numPointsToPlot + 1)
    # model.plot.marginWidthRemainder = totalMarginWidth mod (model.plot.numPointsToPlot + 1)

    echo &"plotContentRect.size.width {model.plot.plotContentRect.size.width}"
    echo &"maxPlottablePoints {model.plot.maxPlottablePoints}"
    echo &"numPointsToPlot {model.plot.numPointsToPlot}"
    echo &"marginWidth {model.plot.marginWidth}"
    echo &"marginWidthRemainder {model.plot.marginWidthRemainder}"
    # echo &"data zoom {(model.plot.model.len.float * model.zoom).int}"

    # Calculate new title positions.
    # title
    if model.plot.title.len > 0:
      model.plot.titleSize = sizeOfString(model.plot.font, model.plot.title)
      model.plot.titlePos = centerInRect(
        model.plot.titleSize,
        newRect(0.0, 0.0, model.frame.size.width, model.plot.boundaries.top.Coord))
    # x axis title
    if model.plot.xTitle.len > 0:
      model.plot.xTitleSize = sizeOfString(model.plot.font, model.plot.xTitle)
      model.plot.xTitlePos = newPoint(
        model.frame.size.width - model.plot.boundaries.left.Coord + model.plot.boundaries.right.Coord,
        model.frame.size.height - model.plot.boundaries.top.Coord + model.plot.boundaries.bottom.Coord / 1.5)
    # y axis title
    if model.plot.yTitle.len > 0:
      model.plot.ytitleSize = sizeOfString(model.plot.font, model.plot.yTitle)
      model.plot.yTitlePos = newPoint(0.0, model.frame.size.height / 2)

    echo &"titlePos {model.plot.titlePos}"

    # if model.plot.maxPlottablePoints > 0:
    #   if model.plot.model.len <= model.plot.maxPlottablePoints:
    #     model.plot.dataRange = 0..model.plot.model.len-1
      # else:
      #   let d = model.model.len - model.maxPoints
      #   if model.scrollOffset.isSome:
      #     let xOffset = model.scrollOffset.get.x.int
      #     if xOffset < 0: # scroll left
      #       let start = max(0, d + model.scrollOffset.get.x.int)
      #       model.dataRange = start..start+model.maxPoints - 1
      #     elif xOffset > 0: # scroll right
      #       var finish = d - xOffset #min(model.model.len - 1, d + model.scrollOffset.get.x.int)
      #       let start = max(0, finish - d)
      #       echo (start, finish)
      #       model.dataRange = d..model.model.len-1
      #     model.scrollOffset.reset
      #   else:
      #     model.dataRange = d..model.model.len-1


  # method onMouseIn*(model: PlotControl, e: var Event) =
  #   echo "onMouseIn"

  # method onMouseOver*(model: PlotControl, e: var Event) =
  #   if insideBounds(model, e.localPosition):
  #     model.hoverPoint = some e.localPosition
  #   else:
  #     model.hoverPoint.reset
  #   model.setNeedsDisplay()

  # method onMouseOut*(model: PlotControl, e: var Event) =
  #   model.hoverPoint.reset

  # method onTouchEv*(model: PlotControl, e: var Event): bool =
  #   case e.buttonState
  #   of bsDown: onMouseDown(model, e)
  #   of bsUp: onMouseUp(model, e)
  #   of bsUnknown: false

  # method onScroll*(model: PlotControl, e: var Event): bool =
  #   # echo "custom scroll ", e.offset
  #   if model.maxPoints > 0 and model.model.len > model.maxPoints:
  #     if e.offset.x < 0: # scroll left
  #       if model.dataRange.a != 0: # already scrolled to end
  #         model.scrollOffset = some e.offset
  #         model.setNeedsDisplay()
  #     elif e.offset.x > 0: # scroll right
  #       if model.dataRange.b != model.model.len-1: # already scrolled to end
  #         model.scrollOffset = some e.offset
  #         model.setNeedsDisplay()
  #   true

# nim r --threads:on nimxplot
when isMainModule:
  import nimx/[window, layout]
  # import nimxplot

  runApplication:
    newFullscreenWindow().makeLayout:
      - PlotControl:
        plot: newPlot(
          title = "Dependency of Y from X",
          yTitle = "Y",
          xTitle = "X",
          minMarkerWidth = 20,
          model = @[
            (x: Coord(0.0), y: Coord(0.0)),
            (x: Coord(10.0), y: Coord(10.0)),
            (x: Coord(20.0), y: Coord(10.0)),
            (x: Coord(60.0), y: Coord(300.0)),
            (x: Coord(100.0), y: Coord(200.0))
          ]
        )
        # lineWidth: 1
        # markerSize: 4
        zoom: 0.5
        drawCrossHair: true
        highlightClosest: true
        leading == super
        trailing == super
        top == super
        bottom == super
