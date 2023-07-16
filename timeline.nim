## Timeline
##
## TODO
## 
## - [ ] 
## 
## JOURNAL
##
## 7/23/22:
##   Thoughts:
##   Work Done:
##

import
  std/[sugar, strutils, strformat, options, tables],
  pkg/nimx/[
    context,
    control,
    event,
    font
  ]

import pkg/print

type
  SeriesView = tuple
    series: Slice[int]
    view: Slice[int]

type
  SeriesBounds* = tuple
    minx, maxx, miny, maxy: float64

type
  Plot* = ref object of RootObj
    title*: string
    xTitle*: string
    yTitle*: string
    leftYAxis*: bool
    boundaries*: tuple[top, bottom, left, right: Natural]
    margin*: tuple[x, y: float32]
    borderWidth*: Natural
    gridLineWidth*: float32
    backgroundColor*: Color
    borderColor*: Color
    gridColor*: Color
    textColor*: Color
    font*: Font
    data*: Table[string, seq[int]]
    x*: string # dataframe key
    y*: string # dataframe key
    # calculated state
    plotRect: Rect
    plotContentRect: Rect
    maxPlottablePoints: int
    numPointsToPlot: int
    markerWidth: int
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
    dataBounds: SeriesBounds
    scale: tuple[x, y: float64]


  AxisLabelPos* {.pure.} = enum
    Top, Bottom, Left, Right

  Axis* = object
    title*: string
    labelPos*: AxisLabelPos
    # Calculated:
    rect: Rect

  FixedXAxis* = object
    margin*: tuple[x, y: float32]
    # Calculated:
    marginWidth: int
    marginWidthRemainder: int

  Rect2dPlot* = ref object of Plot
    minLabelSize*: Natural
    fixedXAxis*: Option[FixedXAxis]
    grid*: Option[tuple[lineWidth: float32, color: Color]]
    axes*: OrderedTable[string, Axis]
    # calculated state
    maxPlottablePoints: int
    numPointsToPlot: int
    markerWidth: int
    gridstep: float32
    dataRange: Slice[int]
    dataBounds: SeriesBounds

  ZoomKind* {.pure.} = enum
    GeometricZoom
    FixedLevelZoom

  ZoomLevelLayout* = tuple
    markerPixelWidth: int
    marginPixelWidth: int

const
  zoomKind = FixedLevelZoom
  fixedZoomLevels* = [
    (markerPixelWidth: 1, marginPixelWidth: 0),
    (1, 1),
    (3, 1),
    (5, 2),
    (9, 4),
    (21, 8)
  ]

type
  PlotControl*[T] = ref object of Control
    ## Contains the properties of an interactive plot.
    plot*: T
    crossHairColor*: Color
    closestPointIndex*: Option[int]
    highlightClosest*: bool
    highlightedPointIndex*: Option[int]
    highlightedPointScaler*: float
    highlightedPointyTitleOffset*: float32
    when zoomKind == GeometricZoom:
      zoomFactor*: float
      minMarginWidth*: int
      minMarkerWidth*: int
      maxMarkerWidthScaler*: float
    elif zoomKind == FixedLevelZoom:
      fixedZoomLevel*: int
    drawCrossHair*: bool
    hoverPoint: Option[Point] ## Cursor position in the plot area.
    scrollOffset: Option[Point]

  BarPlotControl* = PlotControl[BarPlot]
  CandlestickPlotControl* = PlotControl[CandlestickPlot]
  PointPlotControl* = PlotControl[PointPlot]
  LinePlotControl* = PlotControl[LinePlot]


template rect(point, size): untyped =
  let dim = size * 2
  newRect(point.x - size, point.y - size, dim, dim)


func initBoundary(top, bottom, left, right: int): tuple[top, bottom, left, right: Natural] =
  (Natural(top), Natural(bottom), Natural(left), Natural(right))


proc newPlot(
    title = "",
    xTitle = "",
    yTitle = "",
    leftYAxis = true,
    boundaries = initBoundary(30, 30, 1, 30),
    margin = (5'f32, 5'f32),
    borderWidth = 1,
    backgroundColor = newGrayColor(0.5),
    borderColor = blackColor(),
    gridColor = newGrayColor(0.7),
    font = systemFont(),
    textColor = blackColor(),
    data: Table[string, seq[int]],
    x: string,
    y: string
    ): Plot =
  Plot(
    title: title,
    xTitle: xTitle,
    yTitle: yTitle,
    leftYAxis: leftYAxis,
    boundaries: boundaries,
    margin: margin,
    borderWidth: borderWidth,
    backgroundColor: backgroundColor,
    borderColor: borderColor,
    gridColor: gridColor,
    textColor: textColor,
    font: font,
    data: data,
    x: x,
    y: y
  )


proc setZoom*(model: PlotControl, level: int) =
  let level = clamp(level, 0, fixedZoomLevels.high)
  model.fixedZoomLevel = level
  model.plot.markerWidth = fixedZoomLevels[level].markerPixelWidth
  model.plot.marginWidth = fixedZoomLevels[level].marginPixelWidth
  model.setNeedsLayout
  model.setNeedsDisplay


method init(model: PlotControl, r: Rect) =
  procCall model.Control.init(r)
  model.trackMouseOver(true)
  model.backgroundColor = whiteColor()
  model.crossHairColor = blackColor()
  model.highlightedPointScaler = 1.25
  model.highlightedPointyTitleOffset = 20.0
  when zoomKind == GeometricZoom:
    model.minMarkerWidth = 1
    model.minMarginWidth = 0
    model.maxMarkerWidthScaler = 2.0
  elif zoomKind == FixedLevelZoom:
    model.fixedZoomLevel = 3


method afterMakeLayout(model: PlotControl) =
  ## Called after `makeLayout` to test some preconditions.
  doAssert model.plot.data[model.plot.x].len == model.plot.data[model.plot.y].len
  when zoomKind == GeometricZoom:
    model.plot.markerWidth = model.minMarkerWidth
    model.plot.marginWidth = model.minMarginWidth
  elif zoomKind == FixedLevelZoom:
    model.setZoom model.fixedZoomLevel


# type LinePlotControl* = ref object of PlotControl
#   ## Plotting widgets that implements rendering of "y=f(x)" function.
#   lineColor*: Color
#   drawMedian*: bool
#   lineWidth*: float


# method init(model: LinePlotControl, r: Rect) =
#   procCall model.PlotControl.init(r)
#   model.lineWidth = 2.0
#   model.drawMedian = false
#   model.lineColor = blackColor()


# proc newPlotXY*(r: Rect, model: ModelXYColor[float64]): LinePlotControl =
#   result.new()
#   result.model = model
#   result.init(r)


# type PointPlotControl* = ref object of LinePlotControl
#   pointColor*: Color


# method init(model: PointPlotControl, r: Rect) =
#   procCall model.LinePlotControl.init(r)
#   model.pointColor = blackColor()


# proc modelBounds*(model: PointPlotControl): SeriesBounds =
#   model.modelBounds


func translateAndScalePoint(model: PlotControl, point: Point): Point =
  newPoint(
    model.plot.plotContentRect.origin.x + (point.x - model.plot.dataBounds.minx) * model.plot.scale.x,
    (model.plot.plotContentRect.origin.y + (point.y - model.plot.dataBounds.miny) * model.plot.scale.y) - model.plot.plotContentRect.size.height
  )

iterator xy(data: Table[string, seq[int]], x, y: string, dataRange: Slice[int]): Point =
  for i in dataRange:
    yield (float32 data[x][i], float32 data[y][i])

iterator pairs[T](slice: Slice[T]): (int, T) =
  var idx = 0
  for val in slice:
    yield (idx, val)
    inc idx

iterator translatedAndScaledY(model: PlotControl): (int, float) =
  for idx, val in pairs model.plot.dataRange:
    yield (idx, ((float32(model.plot.data[model.plot.y][val]) - model.plot.dataBounds.miny) * model.plot.scale.y) + model.plot.margin.y)

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
  # plot title
  if model.plot.title.len > 0:
    let posCopy = model.plot.titlePos # This point has to be copied because nimx updates the point after writing the text.
    gfx.drawText(model.plot.font,posCopy, model.plot.title)
  # x axis title
  if model.plot.xTitle.len > 0:
    let posCopy = model.plot.xTitlePos # This point has to be copied because nimx updates the point after writing the text.
    gfx.drawText(model.plot.font, posCopy, model.plot.xTitle)
  # # y axis title
  if model.plot.yTitle.len > 0:
    let posCopy = model.plot.yTitlePos # This point has to be copied because nimx updates the point after writing the text.
    gfx.drawText(model.plot.font, posCopy, model.plot.yTitle)


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


func testData(): Table[string, seq[int]] =
  result["time"] = @[]
  result["price"] = @[]
  for i in 0..100000:
    result["time"].add i
    result["price"].add i


proc drawFakeBars(gfx: GraphicsContext, model: PlotControl) =
  ## This is only for development and debugging.
  gfx.strokeColor = whiteColor()
  gfx.fillColor = whiteColor()
  if model.plot.numPointsToPlot > 0:
    for i in 0..model.plot.numPointsToPlot-1:
      gfx.drawRect(newRect(
        model.plot.plotContentRect.origin.x + (model.plot.marginWidthRemainder + model.plot.marginWidth + (model.plot.markerWidth + model.plot.marginWidth) * i).Coord,
        model.plot.plotContentRect.origin.y,
        model.plot.markerWidth.Coord,
        model.plot.plotContentRect.size.height
      ))


proc drawCandleSticks(gfx: GraphicsContext, model: PlotControl) =
  gfx.strokeColor = whiteColor()
  gfx.fillColor = whiteColor()
  for idx, y in model.translatedAndScaledY:
    gfx.drawRect(newRect(
      model.plot.plotContentRect.origin.x + (model.plot.marginWidthRemainder + model.plot.marginWidth + (model.plot.markerWidth + model.plot.marginWidth) * idx).Coord,
      model.plot.plotContentRect.origin.y + model.plot.plotContentRect.size.height - y,
      model.plot.markerWidth.Coord,
      y
    ))


proc drawXAxis(gfx: GraphicsContext, model: PlotControl) =
  gfx.fillColor = model.plot.textColor
  var smallestDelta: float
  # for i in model.plot.dataRange:
  #   echo i


method draw*(model: PlotControl, r: Rect) =
  let gfx = currentContext()
  procCall model.View.draw(r)
  # updateModel(model, r)
  drawBorder(gfx, model)
  drawTitles(gfx, model)
  drawCandleSticks(gfx, model)
  drawXAxis(gfx, model)
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


func contains(rect: Rect, point: Point): bool =
  ## Return `true` if the `point` is inside `rect`.
  if point.x < rect.origin.x or point.x > rect.origin.x + rect.size.width or
     point.y < rect.origin.y or point.y > rect.origin.y + rect.size.height:
    return false
  true


method onMouseDown(model: PlotControl, e: var Event): bool {.base.} =
  template pos: untyped = e.localPosition
  if model.plot.plotContentRect.contains pos:
    let xpart = ((pos.x - model.plot.boundaries.left.float) / (model.bounds.width - model.plot.boundaries.left.float + model.plot.boundaries.right.float))
    let ypart = ((pos.y - model.plot.boundaries.top.float) / (model.bounds.height - model.plot.boundaries.left.float + model.plot.boundaries.right.float))

    let touchPoint = newPoint(
      (xpart * (model.plot.dataBounds.maxx - model.plot.dataBounds.minx)) + model.plot.dataBounds.minx,
      (ypart * (model.plot.dataBounds.maxy - model.plot.dataBounds.miny)) + model.plot.dataBounds.miny
    )

    # for idx, point in model.plot.data[model.plot.x][model.plot.dataRange].pairs():
    #   if point.x > touchPoint.x:
    #     if touchPoint.x - model.model[model.dataRange][idx-1].x < model.model[model.dataRange][idx].x - touchPoint.x:
    #       model.closestPointIndex = some idx-1
    #     else:
    #       model.closestPointIndex = some idx
    #     model.highlightedPointIndex = model.closestPointIndex
    #     break

    model.setNeedsDisplay
  true


method onMouseUp(model: PlotControl, e: var Event): bool {.base.} =
  model.closestPointIndex.reset
  model.highlightedPointIndex.reset
  model.setNeedsDisplay
  true


# iterator xy(): (float, float64) {.closure.} =
#   for x in 0..1000:
#     yield (x.float, (x + 2).float)

func calcPointAndMargins(model: PlotControl) =
  ## Calculate the width of a plot points and the margin between them.
  when zoomKind == GeometricZoom:
    model.plot.maxPlottablePoints = block:
      if model.plot.data[model.plot.x].len > 1:
        var points = model.plot.plotContentRect.size.width.int div model.plot.markerWidth
        # int((model.plot.plotContentRect.size.width + model.plot.marginWidth.float) / float(model.plot.markerWidth + model.plot.marginWidth))
        # XXX: I smell a bug
        while ((points) * model.plot.marginWidth) + points * model.plot.markerWidth > model.plot.plotContentRect.size.width.int:
          dec points
        points
      else:
        1
    let dataZoom = int(model.zoomFactor * model.plot.data[model.plot.x].len.float)
    model.plot.numPointsToPlot = min(dataZoom, model.plot.maxPlottablePoints)
    let totalMarginWidth = (model.plot.plotContentRect.size.width.int - (model.plot.numPointsToPlot * model.plot.markerWidth))
    # debugEcho $model.plot.maxPlottablePoints
    # debugEcho $totalMarginWidth
    model.plot.marginWidth = totalMarginWidth div model.plot.numPointsToPlot
    model.plot.marginWidthRemainder = totalMarginWidth mod model.plot.numPointsToPlot
    # if model.plot.marginWidthRemainder > 1:
    #   inc model.plot.markerWidth
    #   calcPointAndMargins(model)
    debugEcho &"plotContentRect.size.width {model.plot.plotContentRect.size.width}"
    debugEcho &"maxPlottablePoints {model.plot.maxPlottablePoints}"
    debugEcho &"numPointsToPlot {model.plot.numPointsToPlot}"
    debugEcho &"markerWidth {model.plot.markerWidth}"
    debugEcho &"marginWidth {model.plot.marginWidth}"
    debugEcho &"marginWidthRemainder {model.plot.marginWidthRemainder}"
    debugEcho &"data zoomFactor {(model.plot.data[model.plot.x].len.float * model.zoomFactor).int}"
  elif zoomKind == FixedLevelZoom:
    model.plot.maxPlottablePoints = block:
      var points = model.plot.plotContentRect.size.width.int div (model.plot.markerWidth + model.plot.marginWidth)
      while (points * (model.plot.markerWidth + model.plot.marginWidth) + model.plot.marginWidth) > model.plot.plotContentRect.size.width.int:
        dec points
      points
    model.plot.numPointsToPlot = min(model.plot.data[model.plot.x].len, model.plot.maxPlottablePoints)
    model.plot.marginWidthRemainder =
      model.plot.plotContentRect.size.width.int - (model.plot.numPointsToPlot * (model.plot.markerWidth + model.plot.marginWidth) + model.plot.marginWidth)
    debugEcho &"plotContentRect.size.width {model.plot.plotContentRect.size.width}"
    debugEcho &"maxPlottablePoints {model.plot.maxPlottablePoints}"
    debugEcho &"numPointsToPlot {model.plot.numPointsToPlot}"
    debugEcho &"fixed zoom level: {model.fixedZoomLevel}: {fixedZoomLevels[min(fixedZoomLevels.high, model.fixedZoomLevel)]}"
    debugEcho &"marginWidthRemainder {model.plot.marginWidthRemainder}"


when declared View:
  method updateLayout(model: PlotControl) =
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

    calcPointAndMargins(model)

    # Calculate new title positions.
    # title
    if model.plot.title.len > 0:
      model.plot.titleSize = sizeOfString(model.plot.font, model.plot.title)
      model.plot.titlePos = centerInRect(
        model.plot.titleSize,
        newRect(0.0, 0.0, model.frame.size.width, model.plot.boundaries.top.Coord))
    # x axis title
    if model.plot.xTitle.len > 0: # only draw x axis title if it is set
      model.plot.xTitleSize = sizeOfString(model.plot.font, model.plot.xTitle)
      model.plot.xTitlePos = newPoint(model.frame.size.width / 2, model.frame.size.height - model.plot.xTitleSize.height + 1.0)
    # y axis title
    if model.plot.yTitle.len > 0: # only draw y axis title if it is set
      model.plot.ytitleSize = sizeOfString(model.plot.font, model.plot.yTitle)
      model.plot.yTitlePos = newPoint(1.0, model.frame.size.height / 2)

    # Based on the number of points that can be plotted, determine the range of data points to draw.
    if model.plot.maxPlottablePoints > 0:
      if model.plot.data[model.plot.x].len <= model.plot.maxPlottablePoints:
        model.plot.dataRange = 0..model.plot.data[model.plot.x].len-1
      else:
        let d = model.plot.data[model.plot.x].len - model.plot.maxPlottablePoints
        if model.scrollOffset.isSome:
          # Calculate the data range to plot if the plot is has been scrolled.
          let xOffset = model.scrollOffset.get.x.int
          if xOffset < 0: # scroll left
            let start = max(0, d + model.scrollOffset.get.x.int)
            model.plot.dataRange = start..(start + model.plot.maxPlottablePoints - 1)
          elif xOffset > 0: # scroll right
            var finish = d - xOffset #min(model.plot.data[model.plot.x].len - 1, d + model.scrollOffset.get.x.int)
            let start = max(0, finish - d)
            echo (start, finish)
            model.plot.dataRange = d..model.plot.data[model.plot.x].len-1
          model.scrollOffset.reset
        else:
          model.plot.dataRange = d..model.plot.data[model.plot.x].len-1

    # Calculate the min and max values of the data that will be drawn:
    model.plot.dataBounds.minx = float.high
    model.plot.dataBounds.maxx = float.low
    model.plot.dataBounds.miny = float.high
    model.plot.dataBounds.maxy = float.low
    for point in xy(model.plot.data, model.plot.x, model.plot.y, model.plot.dataRange):
      model.plot.dataBounds.minx = min(point.x, model.plot.dataBounds.minx)
      model.plot.dataBounds.miny = min(point.y, model.plot.dataBounds.miny)
      model.plot.dataBounds.maxx = max(point.x, model.plot.dataBounds.maxx)
      model.plot.dataBounds.maxy = max(point.y, model.plot.dataBounds.maxy)

    # Calculate the data scaling factor to fit within the plot's coordinate space:
    model.plot.scale = (
      (model.plot.plotContentRect.size.width - (model.plot.margin.x * 2)) / (model.plot.dataBounds.maxx - model.plot.dataBounds.minx),
      (model.plot.plotContentRect.size.height - (model.plot.margin.y * 2)) / (model.plot.dataBounds.maxy - model.plot.dataBounds.miny)
    )


  method acceptsFirstResponder(model: PlotControl): bool =
    ## Returns `true` so that all events can be processed.
    true

  method onMouseOver(model: PlotControl, e: var Event) =
    if model.plot.plotContentRect.contains e.localPosition:
      model.hoverPoint = some e.localPosition
      model.setNeedsDisplay
    elif model.hoverPoint.isSome:
      model.hoverPoint.reset
      model.setNeedsDisplay

  # method onTouchEv(model: PlotControl, e: var Event): bool =
  #   case e.buttonState
  #   of bsDown: onMouseDown(model, e)
  #   of bsUp: onMouseUp(model, e)
  #   of bsUnknown: false

  # method onKeyDown(model: PlotControl, e: var Event): bool =
  #   print e

  method onTextInput(model: PlotControl, s: string): bool =
    case s
    of "-": # zoom out
      model.setZoom model.fixedZoomLevel - 1
      model.setNeedsLayout
      model.setNeedsDisplay
    of "+": # zoom in
      model.setZoom model.fixedZoomLevel + 1
      model.setNeedsLayout
      model.setNeedsDisplay

  method onScroll(model: PlotControl, e: var Event): bool =
    if e.offset.y != 0:
      # scrolling up zooms out
      # scrolling down zooms in
      model.setZoom model.fixedZoomLevel + e.offset.y.int
    if model.plot.maxPlottablePoints > 0 and model.plot.data[model.plot.x].len > model.plot.maxPlottablePoints:
      if e.offset.x < 0: # scroll left
        if model.plot.dataRange.a != 0: # already scrolled to end
          model.scrollOffset = some e.offset
          model.setNeedsDisplay
      elif e.offset.x > 0: # scroll right
        if model.plot.dataRange.b != model.plot.data[model.plot.x].len-1: # already scrolled to end
          model.scrollOffset = some e.offset
          model.setNeedsDisplay
    true

# nim r --threads:on nimxplot
when isMainModule:
  import nimx/[window, layout]
  # import nimxplot

  runApplication:
    newFullscreenWindow().makeLayout:
      - BarPlotControl:
        plot: newPlot(
          # title = "Dependency of Y from X",
          # yTitle = "Y",
          # xTitle = "X",
          # minMarkerWidth = 20,
          # minMarginWidth = 1,
          data = testData(),
          x = "time",
          y = "price"
        )
        # lineWidth: 1
        # markerSize: 4
        fixedZoomLevel: 3
        # zoomFactor: 0.001
        drawCrossHair: true
        highlightClosest: true
        leading == super
        trailing == super
        top == super
        bottom == super
