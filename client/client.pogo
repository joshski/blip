plastiq = require 'plastiq'
pogo = require 'pogo'

h () =
  a = [arguments.0]
  if ((arguments.1 :: Object) @and (arguments.1.href))
    arguments.1.onclick = router.push

  for (i = 1, i < arguments.length, i := i + 1)
    a.push (arguments.(i))

  plastiq.html.apply (plastiq, a)

window.h = h
window.pogo = pogo

renderPage (model) =
  window.model = model
  h '.blip' (
    h '.page' (
      [
        w <- model.currentPage.widgets
        widget = model.widgetOfType (w.type)
        widget.render (w, h)
      ]
    )
    h '.editor' (
      h 'section.pages' (
        h 'h2' 'Pages'
        h 'ul.pages' [
          page <- model.pages
          h 'li.page' (
            h 'a' {
              href = page.path
              onclick = router.push
            } (page.title)
          )
        ]
      )
      h 'section.current-page' (
        h 'h2' 'Current Page'
        h 'pre' (
          JSON.stringify(model.currentPage, null, 2)
        )
      )
      h 'section.widgets' (
        h 'h2' 'Widgets'
        h '.widgets' (
          [
            w <- model.widgets
            h '.widget' (
              h 'h3' (w.name)
              h 'textarea' {
                binding = [w, 'pogo']
                onblur (e) = compileWidget(w)
                onkeyup (e) = compileWidget(w)
              }
            )
          ]
        )
      )
    )
  )

model = {
  widgetOfType (t) =
    for each @(w) in (self.widgets)
      if (w.name == t)
        return (w)

  pageAtPath (path) =
    for each @(p) in (self.pages)
      if (p.path == path)
        return (p)

  widgets = [
    {
      name = "heading"
      pogo = "h 'h1' (model.text)"
    }
    {
      name = "paragraph"
      pogo = "h 'p' (model.text)"
    }
    {
      name = "link"
      pogo = "h 'a' { href = model.href } (model.text)"
    }
  ]
  pages = [
    {
      path = "/"
      title = "Home Page"
      widgets = [
        { type = "heading", text = "Home Page" }
        { type = "paragraph", text = "Welcome to the site." }
        { type = "link", text = "About us", href = "/about" }
      ]
    }
    {
      path = "/about"
      title = "About Us"
      widgets = [
        { type = "heading", text = "About Us" }
        { type = "paragraph", text = "Coming soon..." }
        { type = "link", text = "Back to home page", href = "/" }
      ]
    }
  ]
}

compileWidget(widget) =
  body = widget.pogo.split("\n").join("\n  ")
  try
    widget.render = @new Function(
      "model"
      "h"
      "var render;\n" + pogo.compile (
        "render() =\n  " + body, { inScope = false }
      ) + "\nreturn render();"
    )
    widget.render (widget, h)
  catch (e)
    widget.render () =
      h 'pre' ("Error in #(widget.name)\n" + e.toString())

for each @(wi) in (model.widgets)
  compileWidget(wi)

router = require 'plastiq/router'
routerify (vdom) =
  if (vdom.tagName == 'A')
    vdom.properties.onclick (e) =
      console.log("E", e.target.pathname)
      router.push(e.target.pathname)
      model.currentPage = model.pageAtPath(e.target.pathname)
      e.preventDefault()
  else if (vdom.children :: Array)
    for each @(child) in (vdom.children)
      routerify (child)

  // console.log(h 'a' { onclick () = true })
  vdom

render (model) =
  router (
    router.page '/' {
      binding = [model, 'currentPage']
      state (params) =
        @new Promise(
          @(result) @{ result(model.pageAtPath('/')) }
        )
    } @{ renderPage (model) }

    router.page '/:path' {
      binding = [model, 'currentPage']
      state (params) =
        @new Promise(
          @(result) @{ result(model.pageAtPath('/' + params.path)) }
        )
    } @{ renderPage (model) }
  )

model.currentPage = model.pageAtPath(window.location.pathname)
console.log ("Loading " + window.location.pathname, model.currentPage)

plastiq.attach (document.body, render, model)
