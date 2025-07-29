import ./property_desc
import macros

macro genVisitorProc(typdesc: typed{nkSym}): untyped=
  result = newNimNode(nnkStmtList)

  let visitorIdent = ident("pv")
  let viewIdent = ident("v")
  var visitBody = newNimNode(nnkStmtList)
  let parent = typdesc.inheritFrom()
  if not parent.isNil:
    visitBody.add quote do:
      procCall `viewIdent`.`parent`.visitProperties(`visitorIdent`)

  for p in typdesc.propertyDescs():
    let plit = newLit(p.name)
    let pname = ident(p.name)
    visitBody.add quote do:
      `visitorIdent`.visitProperty(`plit`, `viewIdent`.`pname`)

  result.add quote do:
    method visitProperties*(`viewIdent`: `typdesc`, `visitorIdent`: var PropertyVisitor)=
      `visitBody`

  # echo "getVisitor result:\n", repr(result)

template genVisitorCodeForView*(c: typed)=
  import ../property_visitor
  genVisitorProc(c)
