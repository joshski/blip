plastiq = require 'plastiq'
pogo = require 'pogo'
h = plastiq.html
window.h = h
window.pogo = pogo

render (model) =
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
              href = '#' + page.title
              onclick (e) =
                e.preventDefault()
                model.currentPage = page

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
      "var render;\n" + pogo.compile("render() =\n  " + body, { inScope = false }) + "\nreturn render();"
    )
    widget.render (widget, plastiq.html)
  catch (e)
    widget.render () = plastiq.html 'pre' ("Error in #(widget.name)\n" + e.toString())

model.currentPage = model.pages.0
for each @(wi) in (model.widgets)
  compileWidget(wi)

plastiq.attach (document.body, render, model)
