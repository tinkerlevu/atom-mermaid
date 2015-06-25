path                  = require 'path'
{CompositeDisposable, Disposable} = require 'atom'
{$, $$$, ScrollView}  = require 'atom-space-pen-views'
_                     = require 'underscore-plus'

module.exports =
  MERMAID_PROTOCOL: "mermaid-preview:"
  MermaidView: class AtomMermaidView extends ScrollView

    atom.deserializers.add(this)

    editorSub           : null
    onDidChangeTitle    : -> new Disposable()
    onDidChangeModified : -> new Disposable()

    @deserialize: (state) ->
      new AtomMermaidView(state)

    @content: ->
      @div class: 'atom-mermaid-preview native-key-bindings', tabindex: -1

    constructor: ({@editorId, filePath}) ->
      super

      if @editorId?
        @resolveEditor(@editorId)
      else
        if atom.workspace?
          @subscribeToFilePath(filePath)
        else
          atom.packages.onDidActivatePackage =>
            @subscribeToFilePath(filePath)

    serialize: ->
      deserializer : 'AtomMermaidView'
      filePath     : @getPath()
      editorId     : @editorId

    destroy: ->
      @editorSub.dispose()

    subscribeToFilePath: (filePath) ->
      @trigger 'title-changed'
      @handleEvents()
      @renderHTML()

    resolveEditor: (editorId) ->
      resolve = =>
        @editor = @editorForId(editorId)

        if @editor?
          @trigger 'title-changed' if @editor?
          @handleEvents()
        else
          atom.workspace?.paneForItem(this)?.destroyItem(this)

      if atom.workspace?
        resolve()
      else
        atom.packages.onDidActivatePackage =>
          resolve()
          @renderHTML()

    editorForId: (editorId) ->
      for editor in atom.workspace.getTextEditors()
        return editor if editor.id?.toString() is editorId.toString()
      null

    handleEvents: =>

      changeHandler = =>
        @renderHTML()
        pane = atom.workspace.paneForURI(@getURI())
        if pane? and pane isnt atom.workspace.getActivePane()
          pane.activateItem(this)

      @editorSub = new CompositeDisposable

      if @editor?
        @editorSub.add @editor.onDidChange _.debounce(changeHandler, 700)
        @editorSub.add @editor.onDidChangePath => @trigger 'title-changed'

    renderHTML: ->
      @showLoading()
      @renderHTMLCode() if @editor?

    renderHTMLCode: (text) ->
      iframe = document.createElement("iframe")
      iframe.setAttribute("sandbox", "allow-scripts allow-same-origin")
      iframe.src = @getPath()
      @html $ iframe
      @trigger('atom-mermaid-preview:html-changed')
      atom.commands.dispatch 'atom-mermaid-preview', 'html-changed'

    getTitle: ->
      if @editor?
        "#{@editor.getTitle()} Preview"
      else
        "Mermaid Preview"

    getURI: ->
      "mermaid-preview://editor/#{@editorId}"

    getPath: ->
      @editor.getPath() if @editor?

    showError: (result) ->
      failureMessage = result?.message

      @html $$$ ->
        @h2 'Previewing Mermaid Failed!!'
        @h3 failureMessage if failureMessage?

    showLoading: ->
      @html $$$ ->
        @div class: 'atom-html-spinner', 'Loading Mermaid Preview\u2026'
