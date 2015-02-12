express = require 'express'
bodyParser = require 'body-parser'

app = express ()

app.use (bodyParser.urlencoded (extended: false))
app.use (express.static 'public')

app.listen (process.env.PORT || 3001)
