import
  std/[tables],
  pkg/iface

iface *Series[T]:
  proc label(): string
  proc add(val: var T)
  # proc format(): string
  proc `[]`(i: Natural): T

type
  IntSeries* = ref object of RootRef
    series*: seq[int]
#   # Column* = concept
#   #   proc type(s: Self): typedesc
#   #   proc label(s: Self): string
  DataFrame* = OrderedTable[string, Series[int]]
#   # IntColumn* = ref object of Column
#   #   series*: seq[int]
#   # FloatColumn* = ref object of Column
#   #   series*: seq[float]

func label(x: IntSeries): string = "int"
func add(x: IntSeries, val: int) =
  x.series.add val
func `[]`(x: IntSeries, i: Natural): int =
  x.series[i]
# func type(x: int): typedesc = typeof int

# func label(x: float): string = "float"
# func type(x: float): typedesc = typeof float

var cols: DataFrame

let a = new IntSeries
a.add 0
cols["a"] = a
# cols["b"] = new FloatColumn(series: @[3.14])
