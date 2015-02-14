plastiq = require 'plastiq'
router = require 'plastiq/router'
pogo = require 'pogo'
language = require 'language'
Firebase = require 'firebase'

firebaseRef = @new Firebase("https://blippy.firebaseio.com/")

updateModelFromFirebase (refresh) =
  firebaseRef.child("site").on "value" @(snapshot)
    value = snapshot.val()
    if (@not value)
      return

    model.widgets = []
    for each @(widget) in (value.widgets || [])
      model.widgets.push (widget)
      compileWidget (widget)

    model.pages = []
    for each @(page) in (value.pages || [])
      model.pages.push (page)

    model.currentPage = model.pageAtPath(window.location.pathname)
    refresh ()

updateFirebaseFromModel () =
  console.log("updating firebase...")
  firebaseRef.set {
    site = {
      widgets = [
        w <- model.widgets
        { name = w.name, pogo = w.pogo }
      ]
      pages = model.pages
    }
  }


h () =
  a = [arguments.0]
  if ((arguments.1 :: Object) @and (arguments.1.href))
    arguments.1.onclick = router.push

  for (i = 1, i < arguments.length, i := i + 1)
    a.push (arguments.(i))

  plastiq.html.apply (plastiq, a)

renderPage (model) =
  h '.blip' (
    plastiq.html.animation(updateModelFromFirebase)
    h '.page' (
      if (model.currentPage)
        compilePage(model.currentPage, model.widgets)
    )
    h '.editor' (
      h 'section.current-page' (
        if (model.currentPage)
          [
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
                  onblur () =
                    updateFirebaseFromModel()

                  onkeyup () = true
                }
              )
            )
          ]
      )
      h 'section.widgets' (
        h 'h2' 'Widgets'
        h '.widgets' (
          [
            w <- model.widgets
            h '.widget' (
              h 'input.name' {
                binding = [w, 'name']
                onchange (e) =
                  compileWidget (w)
                  updateFirebaseFromModel ()
              }
              h 'textarea' {
                binding = [w, 'pogo']
                onblur (e) =
                  compileWidget (w)
                  updateFirebaseFromModel ()

                onkeyup (e) = compileWidget (w)
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
                updateFirebaseFromModel ()
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
              pogo = "'Untitled Page'"
            }
            updateFirebaseFromModel ()
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
  ]

  pages = [
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

window.model = model
window.h = h
window.pogo = pogo

render (model) =
  router (
    router.page '/' {
      binding = [model, 'currentPage']
      state (params) =
        @new Promise(
          @(result) @{ result(model.pageAtPath('/')) }
        )
    } @{ renderPage (model) }

    router.page '/:path*' {
      binding = [model, 'currentPage']
      state (params) =
        @new Promise(
          @(result) @{ result(model.pageAtPath('/' + params.path)) }
        )
    } @{ renderPage (model) }
  )

plastiq.attach (document.body, render, model)
