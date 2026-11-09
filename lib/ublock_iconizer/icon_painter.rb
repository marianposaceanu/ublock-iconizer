# frozen_string_literal: true

module UblockIconizer
  # Inspects and recolours toolbar PNGs with ImageMagick 7.
  class IconPainter
    MISSING_MAGICK_ERROR = 'ImageMagick not found. Install it with: brew install imagemagick'
    # Mean HSL saturation below this counts as grey. The stock maroon icon
    # scores ~0.6; both patched styles stay well under 0.1.
    GREY_SATURATION_LIMIT = 0.15

    def grey?(png)
      saturation = Shell.run!(
        magick, png,
        '-alpha', 'off',
        '-colorspace', 'HSL',
        '-channel', 'G', '-separate', '+channel',
        '-format', '%[fx:mean]', 'info:'
      )
      saturation.to_f < GREY_SATURATION_LIMIT
    end

    def paint(png, paint)
      if paint.detail
        recolour_body_and_detail(png, paint)
      else
        cut_out_template(png, paint)
      end
    end

    private

      def magick
        @magick ||= Shell.which('magick') || raise(Error, MISSING_MAGICK_ERROR)
      end

      # Recolour the shield body and the white bar/border separately, touching
      # RGB only so the anti-aliased alpha edge survives.
      def recolour_body_and_detail(png, paint)
        Shell.run!(
          magick, png,
          '-channel', 'RGB',
          '-fuzz', '25%', '-fill', paint.detail, '-opaque', 'white',
          '-fill', paint.body, '+opaque', paint.detail,
          '+channel',
          png
        )
      end

      # Black on transparent. The white bar and border are cut out, otherwise
      # the shield becomes a solid blob once Safari tints it.
      def cut_out_template(png, paint)
        Shell.run!(
          magick, png,
          '-fuzz', '30%', '-transparent', 'white',
          '-fill', paint.body, '-colorize', '100%',
          png
        )
      end
  end
end
