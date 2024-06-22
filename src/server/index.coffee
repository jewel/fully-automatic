http = require 'http'
url = require 'url'
fs = require 'fs'
{Server} = require 'socket.io'
{Vector} = require './vector'
{convertMap} = require './convert_map'

send404 = (res) ->
  res.writeHead(404)
  res.write('404')
  res.end()
  res

server = http.createServer (req,res) ->
  path = url.parse(req.url).pathname
  path = '/index.html' if path == '/'
  fs.readFile "#{__dirname}/../client/" + path, (err,data) ->
    return send404 res if err
    ext = path.substr path.lastIndexOf( "." ) + 1
    content_type = switch ext
      when 'js' then 'text/javascript'
      when 'css' then 'text/css'
      when 'html' then 'text/html'
      when 'wav' then 'audio/x-wav'
      else
        console.log "Unknown content type: #{ext}"
    res.writeHead 200, 'Content-Type': content_type
    res.write data, 'utf8'
    res.end()

server.listen 4100

io = new Server(server)

console.log "Server running on http://localhost:4100"

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
last_seen = {}

bullets = []
boings = []
deaths = []
baseHits = []

randomInt = (max) ->
  Math.floor Math.random() * max

io.sockets.on 'connection', (client) ->
  client.lastBullet = 0
  client.lastBoing = 0
  client.lastDeath = 0
  client.lastBaseHit = 0

  client.emit 'map', {map}

  client.on 'identity', (msg) ->
    client.identity = msg.identity
    player = players[client.identity]
    if !player
      team = (Object.keys(players).length % 2) + 1
      player =
        team: team
        pos: map.spawns[team].plus new Vector(randomInt(50) - 25, randomInt(50) - 25)
        dir: new Vector 0, 0
      players[client.identity] = player
      client.emit 'player', {player}

  client.on 'base_hit', (msg) ->
    baseHits.push msg
    for base in bases
      base.health--
      base.health = 333 if base.health <= 10

  client.on 'boing', (msg) ->
    boings.push msg

  client.on 'death', (msg) ->
    deaths.push msg

  client.on 'update', (msg) ->
    now = new Date().getTime()
    last_seen[client.id] = now

    player = players[client.identity]
    if !player
      return

    if msg.bullet
      bullet = msg.bullet
      bullet.team = player.team
      bullets.push bullet

    player.pos = Vector.load msg.pos

    others = []
    for identity, p of players
      others.push p unless identity == client.identity

    client.emit 'update',
      tick: tick
      others: others
      bullets: bullets.slice client.lastBullet
      boings: boings.slice client.lastBoing
      deaths: deaths.slice client.lastDeath
      baseHits: baseHits.slice client.lastBaseHit
      bases: bases

    client.lastBullet = bullets.length
    client.lastBoing = boings.length
    client.lastDeath = deaths.length
    client.lastBaseHit = baseHits.length

  client.on 'error', ->
    console.log( "error" )

  client.on 'disconnect', ->
    console.log( "disconnect" )

setInterval(
  ->
    tick++
  16
)
