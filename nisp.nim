# NISP - Lisp in Nim

import strutils, sequtils, re, algorithm

type
  TokenKind = enum
    tkOparen,  # (
    tkCparen,  # )
    tkFloat,   # 5.5
    tkInteger, # 5
    tkString,  # "str"
    tkSymbol,  # +

  TokenType = object
    kind: TokenKind
    reg: Regex

  Token = object
    kind: TokenKind
    value: string

  TreeNodeKind = enum
    Procedure, # (+ 1 2)
    Lambda,    # (lambda (x) (+ x 1))
    Quote,     # '(1 2 3)
    Float,     # 5.5
    Integer,   # 5
    String,    # "str"
    Symbol,    # +

  TreeNode = ref object
    case kind: TreeNodeKind
    of Procedure:
      rator: TreeNode
      rand: seq[TreeNode]
    of Lambda:
      vars: seq[string]
      body: TreeNode
    of Quote, String, Symbol: value: string
    of Integer: intValue: int
    of Float: floatValue: float

# Built-in procs
proc add(a, b: string): string = a & b

proc shift[T](s: var seq[T]): T {.inline, noSideEffect.} =
  result = s[0]
  s = s[1..<s.len]

proc tokenize(inputs: string, ts: seq[TokenType]): seq[Token] =
  var pos: int
  var part: string
  var i: int
  var matches: array[1, string]

  while pos < inputs.len:
    part = inputs[pos..<inputs.len]
    if part.startsWith(" "):
      inc(pos)
      continue

    for t in ts:
      inc(i)
      if part.match(t.reg, matches):
        pos = pos + matches[0].len
        result.add Token(kind: t.kind, value: matches[0])
        break

    if i > ts.len: quit("syntax error", -1)
    else: i = 0

proc parser(ts: var seq[Token]): TreeNode =
  if ts[0].kind == tkOparen: # parse list
    var peek = ts[1]
    if peek.value == "lambda":
      discard ts.shift # consume oparen
      discard ts.shift # consume lambda symbol
      discard ts.shift # consume oparen of args

      # parse lambda args
      var vars: seq[string]
      while ts[0].kind != tkCparen:
        vars.add ts.shift.value

      discard ts.shift # consume cparen

      var body = parser(ts)

      discard ts.shift # consume cparen

      return TreeNode(kind: Lambda, vars: vars, body: body)

    elif peek.value == "quote":
      discard ts.shift # consume oparen
      discard ts.shift # consume quote symbol

      var quoted: seq[string]
      var depth: int
      while true:
        var kind = ts[0].kind
        if kind == tkCparen and depth == 0: break
        if kind == tkOparen: inc(depth)
        if kind == tkCparen: dec(depth)
        quoted.add ts.shift.value

      discard ts.shift # consume cparen

      return TreeNode(kind: Quote, value: quoted.join(" ").replace("( ", "(").replace(" )", ")"))

    else: # parse procedure
      discard ts.shift # consume oparen

      var rator = parser(ts)

      var rand: seq[TreeNode]
      while ts[0].kind != tkCparen:
        rand.add parser(ts)

      discard ts.shift # consume cparen

      return TreeNode(kind: Procedure, rator: rator, rand: rand)

  else: # parse atomic value
    if ts[0].kind == tkInteger: return TreeNode(kind: Integer, intValue: parseInt(ts.shift.value))
    if ts[0].kind == tkFloat: return TreeNode(kind: Float, floatValue: parseFloat(ts.shift.value))
    if ts[0].kind == tkSymbol: return TreeNode(kind: Symbol, value: ts.shift.value)
    return TreeNode(kind: String, value: ts.shift.value)

proc generate(ast: TreeNode): string =
  case ast.kind
  of Procedure:
    result.add "("
    var rands: string
    for (i, arg) in ast.rand.pairs:
      rands.add generate(arg)
      if i < ast.rand.len - 1:
        rands.add " "
    result.add generate(ast.rator) & " " & rands & ")"

  of Lambda:
    result.add "(lambda ("
    for (i, arg) in ast.vars.pairs:
      result.add arg
      if i < ast.vars.len - 1:
        result.add " "
    result.add ") " & generate(ast.body) & ")"

  of Quote: result.add "(quote " & ast.value & ")"
  of Float: result.add $(ast.floatValue)
  of Integer: result.add $(ast.intValue)
  of String: result.add ast.value
  of Symbol: result.add ast.value

proc bytecode(ast: TreeNode): string =
  case ast.kind
  of Procedure:
    var tmp: string
    for (i, arg) in ast.rand.reversed().pairs:
      tmp.add " " & bytecode(arg)
      if i < ast.rand.len - 1:
        tmp.add ","
    result.add tmp & ", " & bytecode(ast.rator)
    if ast.rand.len > 2:
      result.add ", " & bytecode(ast.rator)

  of Lambda: discard

  of Quote: discard

  of Float: discard

  of Integer: result.add "10, " & $ast.intValue

  of Symbol:
    var op = ast.value
    if   op == "+": result.add 2
    elif op == "-": result.add 3
    elif op == "*": result.add 4
    elif op == "/": result.add 5
    elif op == "%": result.add 6
    elif op == ">": result.add 7
    elif op == "<": result.add 8
    elif op == "=": result.add 9
    else: result.add op

  of String: result.add ast.value

# var code = "((lambda (x y) (* x y)) (quote (+ 22 22)) (+ 1 2 (% 9 1 9 5)))"
var code = "(+ 1 2 (+ 3 4))"

var tokens = tokenize(code, @[
  TokenType(kind: tkOparen,  reg: re"(\()"),
  TokenType(kind: tkCparen,  reg: re"(\))"),
  TokenType(kind: tkFloat,   reg: re"(\-?[0-9]+\.[0-9]+)"),
  TokenType(kind: tkInteger, reg: re"(\-?[0-9]+)"),
  TokenType(kind: tkString,  reg: re"""(\"[^\"]*\")"""),
  TokenType(kind: tkSymbol,  reg: re"([a-zA-Z0-9+=!^%*-/`]+)"),
])

# for t in tokens:
#   echo repr(t)

var ast = parser(tokens)
# echo repr(ast)

var generated = generate(ast)
echo "original:  " & code
echo "generated: " & generated
echo "matching: " & $(generated == code)

var bytes = bytecode(ast)
echo "bytes: " & bytes
