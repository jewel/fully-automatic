fs = require 'fs'
{ DOMParser } = require 'xmldom'
{Vector} = require './vector'

scale = 10
map_width = 250 * scale
map_height = 250 * scale

parsePathCommands = (d) ->
  points = []
  regex = / ?([MmLlCcVvZz])? ?(-?\d*\.?\d+(?:e[-+]?\d+)?),(-?\d*\.?\d+(?:e[-+]?\d+)?)/g
  prev = null
  command = null

  while match = regex.exec(d)
    if match[1]
      command = match[1]
    x = parseFloat(match[2]) * scale
    y = parseFloat(match[3]) * scale
    if prev && command && command.toLowerCase() == command
      x += prev.x
      y += prev.y

    x = 0 if x < 0
    x = map_width if x > map_width
    y = 0 if y < 0
    y = map_height if y > map_height

    point = new Vector(Math.round(x), Math.round(y))
    if prev && point.equals(prev)
      continue
    points.push point
    prev = point
  points

mirrorMap = (segments) ->
  newSegments = []
  for segment in segments
    newSegment =
      team: 2
      points: []
    for point in segment.points
      newSegment.points.push new Vector(map_width - point.x, map_height - point.y)
    newSegments.push newSegment
  newSegments

convertMap = (svgContent) ->
  svgContent = fs.readFileSync("#{__dirname}/map.svg", 'utf8')
  doc = new DOMParser().parseFromString(svgContent, 'application/xml')
  paths = doc.getElementsByTagName('path')
  segments = []
  for path in paths
    segments.push
      team: 1
      points: parsePathCommands(path.getAttribute('d'))
  segments = segments.concat mirrorMap segments

  barriers: segments
  width: map_width
  height: map_height
  spawns:
    1: new Vector 800, 300
    2: new Vector 1700, 2200

exports.convertMap = convertMap
