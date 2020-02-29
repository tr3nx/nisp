# NISP - Lisp in Nim

import strutils, re

type
  TokenKind = enum
    tkOparen,  # (
    tkCparen,  # )
    tkInteger, # 5
    tkSymbol,  # +
    tkString,  # "str"

  TokenType = object
    kind: TokenKind
    reg: Regex

  Token = object
    kind: TokenKind
    value: string

  TreeNodeKind = enum
    Procedure, # (+ 1 2)
    Quote,     # '(1 2 3)
    Lambda,    # (lambda (x) (+ x 1))
    Integer,   # 5
    String,    # "str"
    Symbol     # +

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

proc shift[T](s: var seq[T]): T {.inline, noSideEffect.} =
  result = s[0]
  s = s[1..<s.len]

proc tokenize(inputs: string, ts: seq[TokenType]): seq[Token] =
  var pos: int
  var part: string
  var i: int

  while pos < inputs.len:
    part = inputs[pos..<inputs.len]
    if part.startsWith(" "):
      inc(pos)
      continue

    for t in ts:
      inc(i)
      var matches: array[1, string]
      if part.match(t.reg, matches):
        pos = pos + matches[0].len
        result.add Token(kind: t.kind, value: matches[0])
        break

    if i > ts.len:
      echo "syntax error"
      break
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

      discard ts.shift # consume cparen of args
      var body = parser(ts)
      discard ts.shift # consume cparen of lambda

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

      var rator = if ts[0].kind == tkOparen: parser(ts)
                  else: TreeNode(kind: String, value: ts.shift.value)

      var rand: seq[TreeNode]
      while ts[0].kind != tkCparen:
        rand.add parser(ts)

      return TreeNode(kind: Procedure, rator: rator, rand: rand)

  else: # parse atomic value
    if ts[0].kind == tkInteger: 
      return TreeNode(kind: Integer, intValue: parseInt(ts.shift.value))
    else:
      return TreeNode(kind: String, value: ts.shift.value)


var code = "(+ 1 2)"

var tokens = tokenize(code, @[
  TokenType(kind: tkOparen,  reg: re"(\()"),
  TokenType(kind: tkCparen,  reg: re"(\))"),
  TokenType(kind: tkInteger, reg: re"([\-]?[0-9]+(?:[\.]?[0-9]+)?)"),
  TokenType(kind: tkString,  reg: re"""(\"[^\"]*\")"""),
  TokenType(kind: tkSymbol,  reg: re"([a-zA-Z0-9\+\=!^%*-/]+)"),
])

# for t in tokens.reversed:
#   echo repr(t)

var ast = parser(tokens)
echo repr(ast)
