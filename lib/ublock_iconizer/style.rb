# frozen_string_literal: true

module UblockIconizer
  # Colours for one icon state. With a `detail` colour the white bar and border
  # are recoloured too; without one the icon becomes a black template.
  Paint = Struct.new(:body, :detail, keyword_init: true)

  # `on` paints the active icons, `off` the "no filtering" ones. A nil `off`
  # leaves the "no filtering" icons as shipped.
  Style = Struct.new(:name, :on, :off, keyword_init: true)

  # Safari tints a toolbar icon with the accent colour whenever the extension
  # has access to the tab, if the icon is single-coloured or every pixel is
  # near-grey (measured: a 24-unit channel spread still counts as grey, 45
  # does not). The grey style keeps a neutral body and puts the chroma in the
  # bar and border as a very pale blue, so Safari shows it as-is.
  STYLES = {
    'grey' => Style.new(
      name: 'grey',
      on: Paint.new(body: '#828282', detail: '#C8D8F5'),
      off: Paint.new(body: '#B4B4B4', detail: '#C8D8F5')
    ),
    'template' => Style.new(
      name: 'template',
      on: Paint.new(body: 'black'),
      off: nil
    )
  }.freeze
end
