DEVICES     = 1000 * 15 # Only call the API once every 15 seconds.

path        = require 'path'
google      = require 'googleapis'
key         = require './config/analytics.json' # This is the key Google Developer has you download upon service account creation.
express     = require 'express'
http        = require 'http'
https       = require 'https'

analytics   = google.analytics 'v3'
app         = express()
server      = http.createServer app
io          = require('socket.io')(server) # We don't want users to have to refresh the dashboard for data updates.

port = process.env.PORT or 3000

app.use '/static', express.static path.join __dirname, 'node_modules'

app.get '/dashboard', (req, res) ->
    res.sendFile path.join __dirname, 'dashboard.html'

SCOPES = [
    'https://www.googleapis.com/auth/analytics.readonly'
]

jwtClient = new google.auth.JWT key.client_email, null, key.private_key, SCOPES, null

authorize = (metric, dimension, next) ->
    jwtClient.authorize (err, tokens) ->
        if err
            console.error err
            next err
		
        request = analytics.data.realtime.get
            'auth'          : jwtClient
            'ids'           : 'ga:207711148'
            'metrics'       : metric
            'dimensions'    : dimension
            'output'        : 'json'

        next 'https://' + request.host + request.path + '&access_token=' + jwtClient.gtoken.raw_token.access_token

makeRequests = (url, next) ->
    https.get url, (response) ->
        buffer = ''
        response.on 'data', (chunk) ->
            buffer += chunk
        response.on 'end', (err) ->
            next JSON.parse buffer

setInterval authorize, DEVICES, 'rt:activeUsers', 'rt:deviceCategory', (response) ->
    makeRequests response, (data) ->
        io.emit 'devices', data: data

server.listen port, ->
    console.log "Listening on port #{port}"