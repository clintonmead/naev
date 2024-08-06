local luatk = require 'luatk'
local lg = require "love.graphics"
--local lf = require "love.filesystem"
local cmark = require "cmark"
--local utf8 = require "utf8"

local luatk_markdown = {}

local function _nodestr( node_type )
   local types = {
      [cmark.NODE_DOCUMENT] = "DOCUMENT",
      [cmark.NODE_BLOCK_QUOTE] = "BLOCK_QUOTE",
      [cmark.NODE_LIST] = "LIST",
      [cmark.NODE_ITEM] = "ITEM",
      [cmark.NODE_CODE_BLOCK] = "CODE_BLOCK",
      [cmark.NODE_HTML_BLOCK] = "HTML_BLOCK",
      [cmark.NODE_CUSTOM_BLOCK] = "CUSTOM_BLOCK",
      [cmark.NODE_PARAGRAPH] = "PARAGRAPH",
      [cmark.NODE_HEADING] = "HEADING",
      [cmark.NODE_THEMATIC_BREAK] = "THEMATIC_BREAK",
      [cmark.NODE_FIRST_BLOCK] = "FIRST_BLOCK",
      [cmark.NODE_LAST_BLOCK] = "LAST_BLOCK",
      [cmark.NODE_TEXT] = "TEXT",
      [cmark.NODE_SOFTBREAK] = "SOFTBREAK",
      [cmark.NODE_LINEBREAK] = "LINEBREAK",
      [cmark.NODE_CODE] = "CODE",
      [cmark.NODE_HTML_INLINE] = "HTML_INLINE",
      [cmark.NODE_CUSTOM_INLINE] = "CUSTOM_INLINE",
      [cmark.NODE_EMPH] = "EMPH",
      [cmark.NODE_STRONG] = "STRONG",
      [cmark.NODE_LINK] = "LINK",
      [cmark.NODE_IMAGE] = "IMAGE",
      [cmark.NODE_FIRST_INLINE] = "FIRST_INLINE",
      [cmark.NODE_LAST_INLINE] = "LAST_INLINE",
   }
   return types[node_type]
end

local Markdown = {}
setmetatable( Markdown, { __index = luatk.Widget } )
local Markdown_mt = { __index = Markdown }

function luatk_markdown.newMarkdown( parent, doc, x, y, w, h, options )
   options = options or {}
   local wgt = luatk.newWidget( parent, x, y, w, h )
   setmetatable( wgt, Markdown_mt )
   wgt.type    = "markdown"
   --wgt.canfocus = true

   -- Modify for scrollbar
   w = w-12

   -- Some helpers
   wgt.linkfunc = options.linkfunc
   wgt.linktargetfunc = options.linktargetfunc

   local deffont = options.font or luatk._deffont or lg.getFont()
   -- TODO load same font family
   local headerfont = options.fontheader or lg.newFont( math.floor(deffont:getHeight()*1.2+0.5) )

   wgt.blocks = {}
   local block = { type="text", x = 0, y = 0, w=w, h=0, text = "", font=deffont }
   local ty = 0
   local function block_end ()
      if #block.text <= 0 then
         return
      end
      local f = block.font
      local _mw, t = f:getWrap( block.text, w )
      local bh = #t * f:getLineHeight()
      ty = ty + bh
      table.insert( wgt.blocks, block )
      block = { type = "text", x = 0, y = ty, w=w, h=bh, text = "", font=deffont }
   end
   wgt.links = {}
   wgt.wgts = {}
   wgt.focused = nil

   local strong = false
   local emph = false
   local list = cmark.NO_LIST
   local listn
   local linkx, linky, linkname
   for cur, entering, node_type in cmark.walk(doc) do
      --print( string.format("%s - %s [%s]", _nodestr(node_type), cmark.node_get_type_string(cur), tostring(entering) ) )
      if node_type == cmark.NODE_PARAGRAPH then
         if not entering then
            block_end()
         end
      elseif node_type == cmark.NODE_HEADING then
         if entering then
            --block.text = block.text .. "#n"
            block.font = headerfont
            if block.y > 0 then
               ty = ty + headerfont:getHeight()
               block.y = ty
            end
         else
            ty = ty + headerfont:getHeight()*0.5
            block_end()
         end
      elseif node_type == cmark.NODE_STRONG then
         strong = entering
         if strong and not emph then
            block.text = block.text .. "#n"
         elseif not emph and not strong then
            block.text = block.text .. "#0"
         end
      elseif node_type == cmark.NODE_EMPH then
         emph = entering
         if emph and not strong then
            block.text = block.text .. "#n"
         elseif not emph and not strong then
            block.text = block.text .. "#0"
         end
      elseif node_type == cmark.NODE_LINK then
         if entering then
            local bx, by = naev.gfx.printfEnd( block.font.font, block.text, w )
            if wgt.linktargetfunc then
               local target = cmark.node_get_url(cur)
               local found
               found, linkname = wgt.linktargetfunc( target )
               if found then
                  block.text = block.text .. "#b"
               else
                  block.text = block.text .. "#r"
                  linkname = "#r"..linkname.."#0"
               end
            else
               block.text = block.text .. "#b"
               linkname = nil
            end
            linkx = block.x+bx
            linky = block.y+by
         else
            block.text = block.text .. "#0"
            local bx, by = naev.gfx.printfEnd( block.font.font, block.text, w )
            local target = cmark.node_get_url(cur)
            local fh = block.font:getHeight()
            local flh = block.font:getLineHeight()
            if block.y+by == linky then
               -- One line, great!
               table.insert( wgt.links, {
                  x1 = linkx-3,
                  y1 = linky-3,
                  x2 = block.x+bx+3,
                  y2 = block.y+by+fh+3,
                  target = target,
                  name = linkname
               } )
            else
               -- Two lines
               table.insert( wgt.links, {
                  x1 = linkx-3,
                  y1 = linky-3,
                  x2 = w+3,
                  y2 = linky+fh+3,
                  target = target,
                  name = linkname
               } )
               --  More than 2 lines, bad!
               if block.y+by > linky + flh then
                  table.insert( wgt.links, {
                     x1 = -3,
                     y1 = linky+flh-3,
                     x2 = w+3,
                     y2 = block.y+by-flh+fh+3,
                     target = target,
                     name = linkname
                  } )
               end
               table.insert( wgt.links, {
                  x1 = -3,
                  y1 = block.y+by-3,
                  x2 = block.x+bx+3,
                  y2 = block.y+by+fh+3,
                  target = target,
                  name = linkname
               } )
            end
            linkx = nil
            linky = nil
         end
      elseif node_type == cmark.NODE_LIST then
         if entering then
            list = cmark.node_get_list_type( cur )
            listn = 1
         else
            list = cmark.NO_LIST
         end
         ty = ty + headerfont:getHeight()
         block.y = ty
      elseif node_type == cmark.NODE_ITEM then
         if entering then
            if list == cmark.BULLET_LIST then
               block.text = block.text.."・"
            elseif list == cmark.ORDERED_LIST then
               block.text = block.text..string.format(p_("cmark_list","%d. "),listn)
            end
            listn = listn + 1
         end
      elseif node_type == cmark.NODE_FIRST_INLINE or node_type == cmark.NODE_LAST_INLINE then
         local str_type = cmark.node_get_type_string(cur)
         if str_type == "text" and entering then
            local literal = cmark.node_get_literal(cur)
            if options.processliteral then
               block.text = block.text .. options.processliteral( literal )
            else
               block.text = block.text .. literal
            end
         elseif str_type == "image" then
            if not entering then
               local img = lg.newImage( cmark.node_get_url(cur) )
               local iw, ih = img:getDimensions()
               local sx, sy = 1, 1
               if iw > w then
                  sx = w / iw
                  sy = sx
               end
               local imgblock = {
                  type = "image",
                  x = 0,
                  y = ty,
                  w = iw,
                  h = ih,
                  sx = sx,
                  sy = sy,
                  img = img,
               }
               table.insert( wgt.blocks, imgblock )
               ty = ty +ih
               block.y = ty
            end
         end
      elseif node_type == cmark.NODE_HTML_BLOCK then
         local literal = cmark.node_get_literal(cur)
         if options.processhtml then
            local luawgt = options.processhtml( literal )
            if luawgt then
               -- Move the location information to markdown side
               local wx, wy = luawgt.x, luawgt.y+ty
               local ww, wh = luawgt.w, luawgt.h
               luawgt.x = 0
               luawgt.y = 0
               local wgtblock = {
                  type = "widget",
                  x = wx,
                  y = wy,
                  w = ww,
                  h = wh,
                  -- For checking
                  x1 = wx,
                  y1 = wy,
                  x2 = wx+ww,
                  y2 = wy+wh,
                  -- Actual widget
                  wgt = luawgt,
               }
               table.insert( wgt.blocks, wgtblock )
               ty = ty + wh + 20
               block.y = ty
               table.insert( wgt.wgts, wgtblock )
            end
         end
      end
      --print( cmark.node_get_url(cur) )
      --print( cmark.node_get_literal(cur) )
      --print( cmark.node_get_type_string(cur) )
   end

   -- Compute full size
   wgt.scrollh = 0
   if #wgt.blocks > 0 then
      local b = wgt.blocks[#wgt.blocks]
      wgt.scrollh = b.y+b.h
   end
   wgt.scrollh = math.max( 0, wgt.scrollh-wgt.h )
   if wgt.scrollh > 0 then
      wgt.scrolls = true
   end
   wgt.pos = 0

   return wgt
end
function Markdown:update( dt )
   for k,w in ipairs(self.wgts) do
      local wgt  = w.wgt
      if wgt.update then
         wgt:update( dt )
      end
   end
end
function Markdown:draw( wx, wy )
   local x, y, w, h = wx+self.x, wy+self.y, self.w, self.h

   -- Space for scrollbar
   w = w-12

   -- Draw scrollbar
   if self.scrolls then
      local scroll_pos = self.pos / self.scrollh
      luatk.drawScrollbar( x+w, y, 12, h, scroll_pos )
   end

   local sx, sy, sw, sh = luatk.joinScissors( x, y, w, h )
   y = y - self.pos

   --[[
   lg.setColour( 1, 0, 0 )
   for k,l in ipairs(self.links) do
      lg.rectangle( "line", x+l.x1, y+l.y1, l.x2-l.x1, l.y2-l.y1 )
   end
   --]]

   -- Draw the text
   for k,b in ipairs(self.blocks) do
      local bx, by = x+b.x, y+b.y
      lg.setColour( 1, 1, 1 )
      if b.type=="text" then
         lg.printf( b.text, b.font, bx, by, w, "left" )
      elseif b.type=="image" then
         b.img:draw( bx, by, 0, b.sx, b.sy )
      elseif b.type=="widget" then
         b.wgt:draw( bx, by )
      end
   end

   -- Draw focus thingy
   if self.focused then
      local wgt = self.focused.wgt
      local bx, by = x+self.focused.x, y+self.focused.y
      lg.setColour( luatk.colour.focusbtn )
      lg.rectangle( "line", bx-2, by-2, wgt.w+4, wgt.h+4 )
   end

   lg.setScissor( sx, sy, sw, sh )
end
function Markdown:drawover( bx, by )
   local x, y = bx+self.x, by+self.y-self.pos
   for k,l in ipairs(self.links) do
      if l.mouseover then
         lg.rectangle( "line", x+l.x1, y+l.y1, l.x2-l.x1, l.y2-l.y1 )
         if l.name then
            luatk.drawAltText( x+l.x2, y+l.y2, l.name )
         end
      end
   end
end
local function _checkbounds( l, mx, my )
   return not (mx < l.x1 or mx > l.x2 or my < l.y1 or my > l.y2)
end
local scrollbar_h = 30
function Markdown:mmoved( mx, my, dx, dy )
   if self.scrolling then
      self:setPos( (my-scrollbar_h*0.5) / (self.h-scrollbar_h) )
   end

   -- Correct location for scrolling
   my = my + self.pos

   for k,l in ipairs(self.links) do
      local m = l.mouseover
      l.mouseover = _checkbounds( l, mx, my )
      if m ~= l.mouseover then
         luatk.rerender()
      end
   end

   for k,w in ipairs(self.wgts) do
      local wgt  = w.wgt
      local inbounds = _checkbounds( w, mx, my )
      if not wgt._pressed then
         if wgt.mouseover ~= inbounds then
            luatk.rerender()
         end
         wgt.mouseover = inbounds
      end
      if (inbounds or wgt._pressed) and wgt.mmoved then
         wgt.mmoved( wgt, mx, my, dx, dy )
      end
   end
end
function Markdown:pressed( mx, my, button )
   -- Check scrollbar first
   if self.scrolls and mx > self.w-16 then
      self:setPos( (my-scrollbar_h*0.5) / (self.h-scrollbar_h) )
      self.scrolling = true
      return true
   end

   -- Correct location for scrolling
   my = my + self.pos

   -- Check links
   for k,l in ipairs(self.links) do
      if _checkbounds( l, mx, my ) and self.linkfunc then
         luatk.rerender()
         self.focused = nil
         self.linkfunc( l.target )
         return true
      end
   end

   -- Check widget
   for k,w in ipairs(self.wgts) do
      if _checkbounds( w, mx, my ) then
         local wgt  = w.wgt
         wgt._pressed = true
         if wgt.canfocus then
            luatk.rerender()
            self.focused = w
         end
         if wgt.pressed and wgt:pressed( mx, my, button ) then
            luatk.rerender()
            return true
         end
         return true
      end
   end

   -- Clear focus if we didn't click on anything
   self.focused = nil
end
function Markdown:released( mx, my, button )
   self.scrolling = false

   -- Correct location for scrolling
   my = my + self.pos

   -- Check widget
   for k,w in ipairs(self.wgts) do
      local inbounds = _checkbounds(w,mx,my)
      local wgt  = w.wgt
      if wgt._pressed and inbounds and wgt.clicked then
         wgt:clicked( mx, my, button )
         luatk.rerender()
      end
      wgt._pressed = false
      if wgt.released then
         wgt:released()
         luatk.rerender()
      end
      if inbounds then
         if not wgt.mouseover then
            luatk.rerender()
         end
         wgt.mouseover = true
      end
   end
end
function Markdown:setPos( pos )
   if self.scrolls then
      luatk.rerender()
      self.pos = pos * self.scrollh
      self.pos = math.max( 0, math.min( self.scrollh, self.pos ) )
   end
end
function Markdown:wheelmoved( mx, my )
   -- Focus can steal the event now
   if self.focused and self.focused.wgt.wheelmoved then
      local ret = self.focused.wgt:wheelmoved( mx, my )
      if ret then
         return true
      end
   end

   -- Otherwise we handle it
   if my > 0 then
      self:setPos( (self.pos - 50) / self.scrollh )
      return true
   elseif my < 0 then
      self:setPos( (self.pos + 50) / self.scrollh )
      return true
   end
end

return luatk_markdown
