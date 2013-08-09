$ ->
  internalOptions =
    dim: 2150
    trackWidth: 150

  Word = (val, options) ->
    this.options = $.extend(
      scales:
        fill: 0.4
        style: 0.25
      updatesPerStep: 10 # speed, higher is faster
      delays:
        stroke: 0.25
        word: 0.5
    , options, internalOptions)
    this.val = val
    this.utf8code = escape(val).replace(/%u/, "")
    this.strokes = []

    this.canvas = document.createElement("canvas")
    $canvas = $ this.canvas
    $canvas.css "width", this.styleWidth() + "px"
    $canvas.css "height", this.styleHeight() + "px"
    this.canvas.width = this.fillWidth()
    this.canvas.height = this.fillHeight()

    return this

  Word.prototype.init = ->
    this.currentStroke = 0
    this.currentTrack = 0
    this.time = 0.0

  Word.prototype.width = ->
    this.options.dim

  Word.prototype.height = ->
    this.options.dim

  Word.prototype.fillWidth = ->
    this.width() * this.options.scales.fill

  Word.prototype.fillHeight = ->
    this.height() * this.options.scales.fill

  Word.prototype.styleWidth = ->
    this.fillWidth() * this.options.scales.style

  Word.prototype.styleHeight = ->
    this.fillHeight() * this.options.scales.style

  Word.prototype.drawBackground = ->
    ctx = this.canvas.getContext("2d")
    ctx.fillStyle = "#FFF"
    ctx.fillRect(0, 0, this.fillWidth(), this.fillHeight())
    drawBackground(ctx, this.fillWidth())

  Word.prototype.draw = ->
    this.init()
    ctx = this.canvas.getContext("2d")
    ctx.strokeStyle = "#000"
    ctx.fillStyle = "#000"
    ctx.lineWidth = 5
    requestAnimationFrame => this.update()
    this.promise = $.Deferred()

  Word.prototype.update = ->
    return if this.currentStroke >= this.strokes.length
    ctx = this.canvas.getContext("2d")
    stroke = this.strokes[this.currentStroke]
    # will stroke
    if this.time == 0.0
      this.vector =
        x: stroke.track[this.currentTrack + 1].x - stroke.track[this.currentTrack].x
        y: stroke.track[this.currentTrack + 1].y - stroke.track[this.currentTrack].y
        size: stroke.track[this.currentTrack].size or this.options.trackWidth
      ctx.save()
      ctx.beginPath()
      pathOutline(ctx, stroke.outline, this.options.scales.fill)
      ctx.clip()
    for i in [1..this.options.updatesPerStep]
      this.time += 0.02
      this.time = 1 if this.time >= 1
      ctx.beginPath()
      ctx.arc(
        (stroke.track[this.currentTrack].x + this.vector.x * this.time) * this.options.scales.fill,
        (stroke.track[this.currentTrack].y + this.vector.y * this.time) * this.options.scales.fill,
        (this.vector.size * 2) * this.options.scales.fill,
        0,
        2 * Math.PI
      )
      ctx.fill()
      break if this.time >= 1
    delay = 0
    # did track stroked
    if this.time >= 1.0
      ctx.restore()
      this.time = 0.0
      this.currentTrack += 1
    # did stroked
    if this.currentTrack >= stroke.track.length - 1
      this.currentTrack = 0
      this.currentStroke += 1
      delay = this.options.delays.stroke
    # did word stroked
    if this.currentStroke >= this.strokes.length
      setTimeout =>
        this.promise.resolve()
      , this.options.delays.word * 1000
    else
      if delay
        setTimeout =>
          requestAnimationFrame => this.update()
        , delay * 1000
      else
        requestAnimationFrame => this.update()

  drawBackground = (ctx, dim) ->
    ctx.strokeStyle = "#A33"
    ctx.beginPath()
    ctx.lineWidth = 10
    ctx.moveTo(0, 0)
    ctx.lineTo(0, dim)
    ctx.lineTo(dim, dim)
    ctx.lineTo(dim, 0)
    ctx.lineTo(0, 0)
    ctx.stroke()
    ctx.beginPath()
    ctx.lineWidth = 2
    ctx.moveTo(0, dim / 3)
    ctx.lineTo(dim, dim / 3)
    ctx.moveTo(0, dim / 3 * 2)
    ctx.lineTo(dim, dim / 3 * 2)
    ctx.moveTo(dim / 3, 0)
    ctx.lineTo(dim / 3, dim)
    ctx.moveTo(dim / 3 * 2, 0)
    ctx.lineTo(dim / 3 * 2, dim)
    ctx.stroke()

  pathOutline = (ctx, outline, scale) ->
    for path in outline
      switch path.type
        when "M"
          ctx.moveTo path.x * scale, path.y * scale
        when "L"
          ctx.lineTo path.x * scale, path.y * scale
        when "C"
          ctx.bezierCurveTo(
            path.begin.x * scale,
            path.begin.y * scale,
            path.mid.x * scale,
            path.mid.y * scale,
            path.end.x * scale,
            path.end.y * scale
          )
        when "Q"
          ctx.quadraticCurveTo(
            path.begin.x * scale,
            path.begin.y * scale,
            path.end.x * scale,
            path.end.y * scale
          )

  createWordAndView = (element, val, options) ->
    promise = jQuery.Deferred()
    word = new Word(val, options)
    $(element).append word.canvas
    WordStroker.utils.fetchStrokeJSONFromXml(
      "utf8/" + word.utf8code.toLowerCase() + ".xml",
      # success
      (json) ->
        word.strokes = json
        promise.resolve {
          drawBackground: () ->
            word.drawBackground()
          draw: () ->
            word.draw()
        }
      # fail
      , ->
        promise.resolve {
          drawBackground: () ->
            word.drawBackground()
          draw: () ->
            p = jQuery.Deferred()
            $(word.canvas).fadeTo("fast", 0.5, -> p.resolve())
            p
        }
    )
    promise

  createWordsAndViews = (element, words, options) ->
    Array.prototype.map.call words, (word) ->
      return createWordAndView element, word, options

  window.WordStroker or= {}
  window.WordStroker.canvas =
    Word: Word
    createWordsAndViews: createWordsAndViews
