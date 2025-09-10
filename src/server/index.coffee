http = require 'http'
url = require 'url'
fs = require 'fs'
path = require 'path'
crypto = require 'crypto'
selfsigned = require('selfsigned')

{Server} = require 'socket.io'
{Vector} = require './vector'
{convertMap} = require './convert_map'

certPath = path.join __dirname, '../..', 'self-signed.crt'
keyPath = path.join __dirname, '../..', 'self-signed.key'

if !fs.existsSync(certPath) || !fs.existsSync(keyPath)
  pems = selfsigned.generate null, days: 365, keySize: 2048
  fs.writeFileSync certPath, pems.cert
  fs.writeFileSync keyPath, pems.private

options =
  cert: fs.readFileSync certPath
  key: fs.readFileSync keyPath

send404 = (res) ->
  res.writeHead(404)
  res.write('404')
  res.end()
  res

code = ""
code += fs.readFileSync path.join __dirname, '..', 'client/vector.js'
code += fs.readFileSync path.join __dirname, '..', 'client/index.js'

version = crypto.createHash('md5').update(code).digest("hex")

server = http.createServer (req,res) ->
  path = url.parse(req.url).pathname
  path = '/index.html' if path == '/'
  fs.readFile "#{__dirname}/../client/" + path, (err, data) ->
    return send404 res if err
    ext = path.substr path.lastIndexOf( "." ) + 1
    content_type = switch ext
      when 'js' then 'text/javascript'
      when 'css' then 'text/css'
      when 'html' then 'text/html'
      when 'wav' then 'audio/x-wav'
      else
        'application/octet-stream'
    res.writeHead 200, 'Content-Type': content_type
    if path == '/index.html'
      # This is one way to cachebust the code during development
      data = data.toString('utf8').replace 'CODE_HERE', code
    res.write data
    res.end()

server.listen 4100

io = new Server(server)

console.log "Server running on https://localhost:4100"

tick = 0
map = convertMap()
bases = [
  {
    team: 1
    pos: new Vector 0, 0
    health: 333
  }
  {
    team: 2
    pos: new Vector map.width, map.height
    health: 333
  }
]

players = {}

events = []
deletedEvents = 0
addEvent = (type, event) ->
  events.push [tick, type, event]
  if events.length % 1000 == 0
    # clean out old events so we don't run out of RAM
    oldLength = events.length
    events = events.filter (e) ->
      e[0] > tick - 240
    deletedEvents += oldLength - events.length

io.sockets.on 'connection', (client) ->
  client.lastEvent = deletedEvents + events.length

  client.emit 'map', {map}

  client.emit 'version', version

  client.on 'identity', (msg) ->
    client.identity = msg.identity
    player = players[client.identity]
    if !player
      team = (Object.keys(players).length % 2) + 1
      player =
        team: team
      players[client.identity] = player

    player.connected = true
    client.emit 'player', {player}

  client.on 'base_hit', (msg) ->
    addEvent 'base_hit', msg
    for base in bases
      base.health--
      base.health = 333 if base.health <= 10

  client.on 'boing', (msg) ->
    addEvent 'boing', msg

  client.on 'death', (msg) ->
    addEvent 'death', msg

  client.on 'voice', (data) ->
    player = players[client.identity]
    return unless player
    addEvent 'voice',
      pos: player.pos
      dir: player.dir
      owner: client.identity
      data: data

  client.on 'update', (msg) ->
    player = players[client.identity]
    if !player
      return

    if msg.bullet
      bullet = msg.bullet
      bullet.team = player.team
      addEvent 'bullet', bullet

    player.pos = Vector.load msg.pos

    others = []
    for identity, p of players
      continue if identity == client.identity
      continue unless p.connected
      others.push p

    firstEvent = client.lastEvent - deletedEvents
    firstEvent = 0 if firstEvent < 0

    client.emit 'update',
      tick: tick
      others: others
      events: events.slice firstEvent
      bases: bases

    client.lastEvent = deletedEvents + events.length

  client.on 'error', ->
    console.log( "error" )

  client.on 'disconnect', ->
    player = players[client.identity]
    if player
      player.connected = false

setInterval(
  ->
    tick++
  16
)
