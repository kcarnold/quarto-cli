-- render-asciidoc.lua
-- Copyright (C) 2020-2022 Posit Software, PBC


local kAsciidocNativeCites = 'use-asciidoc-native-cites'

function renderAsciidoc()   

  -- This only applies to asciidoc output
  if not quarto.doc.isFormat("asciidoc") then
    return {}
  end

  local hasMath = false

  return {
    Meta = function(meta)
      if hasMath then
        meta['asciidoc-stem'] = 'latexmath'
        return meta
      end 
    end,
    Math = function(el)
      hasMath = true;
    end,
    Cite = function(el) 
      -- If quarto is going to be processing the cites, go ahead and convert
      -- them to a native cite
      if param(kAsciidocNativeCites) then
        local citesStr = table.concat(el.citations:map(function (cite) 
          return '<<' .. cite.id .. '>>'
        end))
        return pandoc.RawInline("asciidoc", citesStr);
      end
    end,
    Callout = function(el) 
      -- callout -> admonition types pass through
      local admonitionType = el.type:upper();

      -- render the callout contents
      local admonitionContents = pandoc.write(pandoc.Pandoc(el.content), "asciidoc")

      local admonitionStr;
      if el.caption then
        -- A captioned admonition
        local admonitionCaption = pandoc.write(pandoc.Pandoc(el.caption), "asciidoc")
        admonitionStr = "[" .. admonitionType .. "]\n." .. admonitionCaption .. "====\n" .. admonitionContents .. "====\n\n" 
      else
        -- A captionless admonition
          admonitionStr = "[" .. admonitionType .. "]\n====\n" .. admonitionContents .. "====\n\n" 
      end
      return pandoc.RawBlock("asciidoc", admonitionStr)
    end,
    Inlines = function(el)
      -- Walk inlines and see if there is an inline code followed directly by a note. 
      -- If there is, place a space there (because otherwise asciidoctor may be very confused)
      for i, v in ipairs(el) do

        if v.t == "Code" then
          if el[i+1] and el[i+1].t == "Note" then

            local noteEl = el[i+1]
            -- if the note contains a code inline, we need to add a space
            local hasCode = false
            pandoc.walk_inline(noteEl, {
              Code = function(_el)
                hasCode = true
              end
            })

            -- insert a space
            if hasCode then
              table.insert(el, i+1, pandoc.RawInline("asciidoc", "{empty}"))
            end
          end
        end
        
      end
      return el

    end
  }
end

