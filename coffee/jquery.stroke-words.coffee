isCanvasSupported = () ->
  document.createElement("canvas")?.getContext("2d")

$ = jQuery

$.fn.extend
  strokeWords: (words, options) ->
    return null if words is undefined or words is ""

    options = $.extend(
      svg: !isCanvasSupported()
      single: true
    , options)

    this.each(() ->
      if options.svg
        window.WordStroker.raphael.strokeWords this, words
      else
        promises = window.WordStroker.canvas.createWordsAndViews(this, words, options)
        if not options.single
          promises.forEach (p) ->
            p.then (word) ->
              word.drawBackground()
        i = 0
        next = ->
          if i < promises.length
            promises[i++].then (word) ->
              if options.single
                word.drawBackground()
              word.draw().then (word) ->
                if options.single and i < promises.length
                  word.remove()
                next()
        next()
    ).data("strokeWords",
      play: null
    )
