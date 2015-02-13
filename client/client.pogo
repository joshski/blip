plastiq = require 'plastiq'
router = require 'plastiq/router'
pogo = require 'pogo'
language = require 'language'

h () =
  a = [arguments.0]
  if ((arguments.1 :: Object) @and (arguments.1.href))
    arguments.1.onclick = router.push

  for (i = 1, i < arguments.length, i := i + 1)
    a.push (arguments.(i))

  plastiq.html.apply (plastiq, a)

renderPage (model) =

  compiled = compilePage(model.currentPage, model.widgets)

  h '.blip' (
    h '.page' (
      compiled
    )
    h '.editor' (
      h 'section.current-page' (
        h '.property' (
          h '.name' 'title'
          h '.value' (
            h 'input' { binding = [model.currentPage, 'title'] }
          )
        )
        h '.property' (
          h '.name' 'path'
          h '.value' (
            h 'input' { binding = [model.currentPage, 'path'] }
          )
        )
        h '.property' (
          h '.name' 'body'
          h '.value' (
            h 'textarea.body' {
              binding = [model.currentPage, 'pogo']
              onblur () = true
              onkeyup () = true
            }
          )
        )
      )
      h 'section.widgets' (
        h 'h2' 'Widgets'
        h '.widgets' (
          [
            w <- model.widgets
            h '.widget' (
              h 'input.name' { binding = [w, 'name'] }
              h 'textarea' {
                binding = [w, 'pogo']
                onblur (e) = compileWidget(w)
                onkeyup (e) = compileWidget(w)
              }
            )
          ]
          h '.widget' (
            h 'button' {
              onclick (e) =
                model.widgets.push {
                  name = 'untitledWidget'
                  pogo = "'hello'"
                }
            } 'New Widget'
          )
        )
      )
      h 'section.pages' (
        h 'h2' 'Pages'
        h 'ul.pages' [
          page <- model.pages
          h 'li.page' (
            if (page == model.currentPage)
              h 'span' (page.title)
            else
              h 'a' {
                href = page.path
                onclick = router.push
              } (page.title)
          )
        ]
        h 'button' {
          onclick () =
            model.pages.push {
              path = "/untitled"
              title = "Untitled Page"
              pogo = "'Unititled Page'"
            }
        } 'New Page'
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
      name = "layout"
      pogo = "h '.my-website' (\n  h 'h1' 'My Awesome Site'\n  model\n)"
    }
    {
      name = "heading"
      pogo = "h 'h2' (model.text)"
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
      pogo = "layout(heading (text: 'Home Page'))"
    }
    {
      path = "/about"
      title = "About Us"
      pogo = "layout (\n  heading (text: 'About Us')\n  paragraph (text: 'Coming soon...')\n)"
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
  catch (e)
    widget.render () =
      h 'pre' ("Error compiling widget: #(widget.name)\n" + e.toString())

widgetRenderer (widget) =
  @(opts) @{
    try
      widget.render (opts, h)
    catch (e)
      h 'pre' ("Error rendering widget: #(widget.name)\n" + e.toString())
  }

compilePage(page, widgets) =
  body = page.pogo.split("\n").join("\n  ")
  try
    r = @new Function(
      "model"
      "h"
      "var nodes;\n" + pogo.compile (
        "nodes = [\n  " + body + "\n]", { inScope = false }
      ) + "; return nodes;"
    )

    dsl = {}
    for each @(widget) in (widgets)
      dsl.(widget.name) = widgetRenderer(widget)

    lang = language(dsl)

    lang (r)
  catch (e)
    h 'pre' ("Error compiling page: #(page.title)\n" + e.toString())

for each @(wi) in (model.widgets)
  compileWidget(wi)

window.model = model
window.h = h
window.pogo = pogo


render (model) =
  router (
    router.page '/' {
      binding = [model, 'currentPage']
      state (params) =
        console.log("ROOT!")
        @new Promise(
          @(result) @{ result(model.pageAtPath('/')) }
        )
    } @{ renderPage (model) }

    router.page '/:path*' {
      binding = [model, 'currentPage']
      state (params) =
        console.log("PATH!")
        @new Promise(
          @(result) @{ result(model.pageAtPath('/' + params.path)) }
        )
    } @{ renderPage (model) }
  )

model.currentPage = model.pageAtPath(window.location.pathname)
console.log ("Loading " + window.location.pathname, model.currentPage)

plastiq.attach (document.body, render, model)
