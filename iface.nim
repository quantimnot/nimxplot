import std/options

type
  Iface*[T] = ref object
    original*: ref RootObj
    vtables*: seq[ref RootObj]
    vtable*: T
  None = ref object of RootObj

let noneVtable: None = new(None)

proc to*[S, T](self: S, t: typedesc[T]): Option[T] =
  var res: T
  var vt: seq[ref RootObj]

  when compiles(vt = self.vtables()):
    vt = self.vtables()
  else:
    vt = self.vtables

  for i, v in vt.pairs():
    if v of typeof(res.vtable):
      return some(Iface[typeof(res.vtable)](
        original: cast[ref RootObj](self),
        vtables: vt,
        vtable: cast[typeof(res.vtable)](v)))
  result = none T

########################

type
  ReaderVtable*[S, T] = ref object of RootObj
    read*: proc(self: S, buffer: openArray[T]): Option[int]

  WriterVtable*[S, T] = ref object of RootObj
    write*: proc(self: S, buffer: openArray[T], num: ref int)

  Reader*[T] = Iface[ReaderVtable[ref RootObj, T]]
  Writer*[T] = Iface[WriterVtable[ref RootObj, T]]

# Should be auto generated from vtable type if possible
proc read*[T](self: Reader[T], buffer: openArray[T]): Option[int] =
  self.vtable.read(self.original, buffer)

# Should be auto generated from vtable type if possible
proc write*[T](self: Writer[T], buffer: openArray[T], num: ref int = nil) =
  self.vtable.write(self.original, buffer, num)

########################

type Null[T] = ref object of RootObj

proc read*[T](self: Null[T], buffer: openArray[T]): Option[int] =
  result = some(buffer.len)

# Should be auto generated as this is just a type cast for self
proc readImplem[T](self: ref RootObj, buffer: openArray[T]): Option[int] =
  cast[Null[T]](self).read(buffer)

proc write*[T](self: Null[T], buffer: openArray[T], num: ref int) =
  echo "write"
  discard

# Should be auto generated as this is just a type cast for self
proc writeImplem[T](self: ref RootObj, buffer: openArray[T], num: ref int) =
  cast[Null[T]](self).write(buffer, num)

# Should be auto generated if possible although manual declaration makes it explicit
proc vtables*[T](self: Null[T]): seq[ref RootObj] =
  let reader = ReaderVtable[ref RootObj, T](
    read: readImplem
  )
  let writer = WriterVtable[ref RootObj, T](
    write: writeImplem
  )
  return @[
    cast[ref RootObj](reader),
    cast[ref RootObj](writer)
  ]

var foo = new(Null[char])
var reader = foo.to(Reader[char]).get
echo reader.read(@['q'])
var writer = reader.to(Writer[char]).get
writer.write(@['q'], nil)
