{-# LANGUAGE RecordWildCards #-}

module Monomer.Widgets.Util.Style (
  GetBaseStyle(..),
  ActiveStyleCfg(..),
  activeTheme,
  activeTheme_,
  activeStyle,
  activeStyle_,
  focusedStyle,
  styleStateChanged,
  initNodeStyle,
  handleStyleChange
) where

import Control.Applicative ((<|>))
import Control.Lens ((&), (^.), (^?), (.~), (<>~), _Just, _1)
import Data.Bits (xor)
import Data.Default
import Data.Maybe
import Data.Sequence (Seq(..), (<|), (|>))

import qualified Data.Sequence as Seq

import Monomer.Core
import Monomer.Event
import Monomer.Graphics
import Monomer.Widgets.Util.Focus
import Monomer.Widgets.Util.Hover
import Monomer.Widgets.Util.Widget

import qualified Monomer.Lens as L

type IsHovered s e = WidgetEnv s e -> WidgetNode s e -> Bool
type IsFocused s e = WidgetEnv s e -> WidgetNode s e -> Bool
type IsActive s e = WidgetEnv s e -> WidgetNode s e -> Bool

type GetBaseStyle s e
  = WidgetEnv s e
  -> WidgetNode s e
  -> Maybe Style

data ActiveStyleCfg s e = ActiveStyleCfg {
  _ascIsHovered :: IsHovered s e,
  _ascIsFocused :: IsFocused s e,
  _ascIsActive :: IsActive s e
}

instance Default (ActiveStyleCfg s e) where
  def = ActiveStyleCfg {
    _ascIsHovered = isNodeHovered,
    _ascIsFocused = isNodeFocused,
    _ascIsActive = isNodeActive
  }

-- Do not use in findByPoint
activeStyle :: WidgetEnv s e -> WidgetNode s e -> StyleState
activeStyle wenv node = activeStyle_ def wenv node

activeStyle_ :: ActiveStyleCfg s e -> WidgetEnv s e -> WidgetNode s e -> StyleState
activeStyle_ config wenv node = fromMaybe def styleState where
  Style{..} = node ^. L.info . L.style
  mousePos = wenv ^. L.inputStatus . L.mousePos
  isEnabled = node ^. L.info . L.enabled
  isHover = _ascIsHovered config wenv node
  isFocus = _ascIsFocused config wenv node
  isActive = _ascIsActive config wenv node
  styleState
    | not isEnabled = _styleDisabled
    | isActive = _styleActive
    | isHover && isFocus = _styleFocusHover
    | isHover = _styleHover
    | isFocus = _styleFocus
    | otherwise = _styleBasic

focusedStyle :: WidgetEnv s e -> WidgetNode s e -> StyleState
focusedStyle wenv node = focusedStyle_ isNodeHovered wenv node

focusedStyle_ :: IsHovered s e -> WidgetEnv s e -> WidgetNode s e -> StyleState
focusedStyle_ isHoveredFn wenv node = fromMaybe def styleState where
  Style{..} = node ^. L.info . L.style
  isHover = isHoveredFn wenv node
  styleState
    | isHover = _styleFocusHover
    | otherwise = _styleFocus

activeTheme :: WidgetEnv s e -> WidgetNode s e -> ThemeState
activeTheme wenv node = activeTheme_ isNodeHovered wenv node

activeTheme_ :: IsHovered s e -> WidgetEnv s e -> WidgetNode s e -> ThemeState
activeTheme_ isHoveredFn wenv node = themeState where
  theme = _weTheme wenv
  mousePos = wenv ^. L.inputStatus . L.mousePos
  isEnabled = node ^. L.info . L.enabled
  isHover = isHoveredFn wenv node
  isFocus = isNodeFocused wenv node
  isActive = isNodeActive wenv node
  themeState
    | not isEnabled = _themeDisabled theme
    | isActive = _themeActive theme
    | isHover && isFocus = _themeFocusHover theme
    | isHover = _themeHover theme
    | isFocus = _themeFocus theme
    | otherwise = _themeBasic theme

styleStateChanged :: WidgetEnv s e -> WidgetNode s e -> SystemEvent -> Bool
styleStateChanged wenv node evt = hoverChanged || focusChanged where
  -- Hover
  hoverChanged = isOnEnter evt || isOnLeave evt
  -- Focus
  focusChanged = isOnFocus evt || isOnBlur evt

initNodeStyle
  :: GetBaseStyle s e
  -> WidgetEnv s e
  -> WidgetNode s e
  -> WidgetNode s e
initNodeStyle getBaseStyle wenv node = newNode where
  nodeStyle = mergeBasicStyle $ node ^. L.info . L.style
  baseStyle = mergeBasicStyle $ fromMaybe def (getBaseStyle wenv node)
  themeStyle = baseStyleFromTheme (_weTheme wenv)
  newNode = node
    & L.info . L.style .~ (themeStyle <> baseStyle <> nodeStyle)

handleStyleChange
  :: WidgetEnv s e
  -> Path
  -> StyleState
  -> Bool
  -> WidgetNode s e
  -> SystemEvent
  -> Maybe (WidgetResult s e)
  -> Maybe (WidgetResult s e)
handleStyleChange wenv target style doCursor node evt result = newResult where
  newResult = handleSizeChange wenv target evt node result
    & handleCursorChange wenv target evt style node

handleSizeChange
  :: WidgetEnv s e
  -> Path
  -> SystemEvent
  -> WidgetNode s e
  -> Maybe (WidgetResult s e)
  -> Maybe (WidgetResult s e)
handleSizeChange wenv target evt oldNode result = newResult where
  baseResult = fromMaybe (resultWidget oldNode) result
  newNode = baseResult ^. L.node
  -- Size
  oldSizeReqW = oldNode ^. L.info . L.sizeReqW
  oldSizeReqH = oldNode ^. L.info . L.sizeReqH
  newSizeReqW = newNode ^. L.info . L.sizeReqW
  newSizeReqH = newNode ^. L.info . L.sizeReqH
  sizeReqChanged = oldSizeReqW /= newSizeReqW || oldSizeReqH /= newSizeReqH
  -- Hover drag changed (if dragging, Enter/Leave is not sent)
  prevInVp = isPointInNodeVp (wenv ^. L.inputStatus . L.mousePosPrev) newNode
  currInVp = isPointInNodeVp (wenv ^. L.inputStatus . L.mousePos) newNode
  path = newNode ^. L.info . L.path
  pressedPath = wenv ^. L.mainBtnPress ^? _Just . _1
  hoverDragChg = Just path == pressedPath && prevInVp /= currInVp
  -- Result
  renderReq = isOnEnter evt || isOnLeave evt || hoverDragChg
  resizeReq = [ ResizeWidgets | sizeReqChanged ]
  enterReq = [ RenderOnce | renderReq ]
  reqs = resizeReq ++ enterReq
  newResult
    | not (null reqs) = Just $ baseResult
      & L.requests <>~ Seq.fromList reqs
    | otherwise = result

handleCursorChange
  :: WidgetEnv s e
  -> Path
  -> SystemEvent
  -> StyleState
  -> WidgetNode s e
  -> Maybe (WidgetResult s e)
  -> Maybe (WidgetResult s e)
handleCursorChange wenv target evt style oldNode result = newResult where
  baseResult = fromMaybe (resultWidget oldNode) result
  baseReqs = baseResult ^. L.requests
  node = baseResult ^. L.node
  -- Cursor
  widgetId = node ^. L.info . L.widgetId
  path = node ^. L.info . L.path
  isTarget = path == target
  hasCursor = isJust (style ^. L.cursorIcon)
  isPressed = isNodePressed wenv node
  (curPath, curIcon) = fromMaybe def (wenv ^. L.cursor)
  newIcon = fromMaybe CursorArrow (style ^. L.cursorIcon)
  setCursor = hasCursor
    && isCursorEvt evt
    && curIcon /= newIcon
  resetCursor = isTarget
    && not hasCursor
    && isCursorEvt evt
    && not isPressed
    && curPath == path
  -- Result
  newResult
    | setCursor = Just $ baseResult
      & L.requests .~ SetCursorIcon widgetId newIcon <| baseReqs
    | resetCursor = Just $ baseResult
      & L.requests .~ baseReqs |> ResetCursorIcon widgetId
    | otherwise = result

baseStyleFromTheme :: Theme -> Style
baseStyleFromTheme theme = style where
  style = Style {
    _styleBasic = fromThemeState (_themeBasic theme),
    _styleHover = fromThemeState (_themeHover theme),
    _styleFocus = fromThemeState (_themeFocus theme),
    _styleFocusHover = fromThemeState (_themeFocusHover theme),
    _styleActive = fromThemeState (_themeActive theme),
    _styleDisabled = fromThemeState (_themeDisabled theme)
  }
  fromThemeState tstate = Just $ def {
    _sstFgColor = Just $ _thsFgColor tstate,
    _sstHlColor = Just $ _thsHlColor tstate,
    _sstText = Just $ _thsText tstate
  }

mergeBasicStyle :: Style -> Style
mergeBasicStyle st = newStyle where
  focusHover = _styleHover st <> _styleFocus st <> _styleFocusHover st
  active = focusHover <> _styleActive st
  newStyle = Style {
    _styleBasic = _styleBasic st,
    _styleHover = _styleBasic st <> _styleHover st,
    _styleFocus = _styleBasic st <> _styleFocus st,
    _styleFocusHover = _styleBasic st <> focusHover,
    _styleActive = _styleBasic st <> active,
    _styleDisabled = _styleBasic st <> _styleDisabled st
  }

isCursorEvt :: SystemEvent -> Bool
isCursorEvt Enter{} = True
isCursorEvt Click{} = True
isCursorEvt DblClick{} = True
isCursorEvt ButtonAction{} = True
isCursorEvt Move{} = True
isCursorEvt _ = False
