{-# LANGUAGE RecordWildCards #-}

module Potato.Flow.Controller.Manipulator.Select (
  SelectHandler(..)
  , layerMetaMap_isInheritHiddenOrLocked
  , layerMetaMap_isInheritHidden
) where

import           Relude

import Potato.Flow.Controller.Manipulator.Box
import           Potato.Flow.BroadPhase
import           Potato.Flow.Controller.Handler
import           Potato.Flow.Controller.Input
import Potato.Flow.Controller.OwlLayers
import           Potato.Flow.Controller.Types
import           Potato.Flow.Math
import           Potato.Flow.SEltMethods
import           Potato.Flow.SElts
import           Potato.Flow.OwlItem
import Potato.Flow.OwlState
import           Potato.Flow.OwlItem
import Potato.Flow.Owl

import           Data.Default
import Data.Foldable (maximumBy)
import qualified Data.IntMap as IM
import qualified Data.Sequence                  as Seq
import           Control.Exception                         (assert)


layerMetaMap_isInheritHiddenOrLocked :: OwlTree -> REltId -> LayerMetaMap -> Bool
layerMetaMap_isInheritHiddenOrLocked ot rid lmm = case IM.lookup rid lmm of
  -- these may both be false, but it may inherit from a parent where these are true therefore we still need to walk up the tree if these are both false
  Just lm | _layerMeta_isLocked lm || _layerMeta_isHidden lm -> True
  _ -> case IM.lookup rid (_owlTree_mapping ot) of
    Nothing -> False
    Just (oem,_) -> layerMetaMap_isInheritHiddenOrLocked ot (_owlItemMeta_parent oem) lmm

layerMetaMap_isInheritHidden :: OwlTree -> REltId -> LayerMetaMap -> Bool
layerMetaMap_isInheritHidden ot rid lmm = case IM.lookup rid lmm of
  Just lm | _layerMeta_isHidden lm -> True
  _ -> case IM.lookup rid (_owlTree_mapping ot) of
    Nothing -> False
    Just (oem,_) -> layerMetaMap_isInheritHidden ot (_owlItemMeta_parent oem) lmm

selectBoxFromRelMouseDrag :: RelMouseDrag -> LBox
selectBoxFromRelMouseDrag (RelMouseDrag MouseDrag {..}) = r where
  LBox pos' sz' = make_lBox_from_XYs _mouseDrag_to _mouseDrag_from
  -- always expand selection by 1
  r = LBox pos' (sz' + V2 1 1)

-- TODO ignore locked and hidden elements here
-- for now hidden + locked elements ARE inctluded in BroadPhaseState
selectMagic :: OwlPFState -> LayerMetaMap -> BroadPhaseState -> RelMouseDrag -> Selection
selectMagic pfs lmm bps rmd = r where
  selectBox = selectBoxFromRelMouseDrag rmd
  boxSize = lBox_area selectBox
  singleClick = boxSize == 1

  isboxshaped sowl = case _superOwl_elt sowl of
    OwlItem _ (OwlSubItemBox _) -> True
    OwlItem _ (OwlSubItemTextArea _) -> True
    _ -> False

  unculledrids = broadPhase_cull_includeZero selectBox (_broadPhaseState_bPTree bps)
  unculledsowls = fmap (\rid ->  owlTree_mustFindSuperOwl (_owlPFState_owlTree pfs) rid) unculledrids
  selectedsowls'' = flip filter unculledsowls $ \case
    -- if it's box shaped, there's no need to test for intersection as we already know it intersects based on broadphase
    sowl | isboxshaped sowl -> True

    -- TODO you need to pass / return render cache here
    sowl -> doesOwlSubItemIntersectBox (_owlPFState_owlTree pfs) selectBox (superOwl_owlSubItem sowl)


  -- remove lock and hidden stuff
  selectedsowls' = flip filter selectedsowls'' $ \sowl -> not (layerMetaMap_isInheritHiddenOrLocked (_owlPFState_owlTree pfs) (_superOwl_id sowl) lmm)

  -- TODO consider using makeSortedSuperOwlParliament instead (prob a little faster?)
  selectedsowls = if singleClick
    -- single click, select top elt only
    then case selectedsowls' of
      [] -> []
      _ ->  [maximumBy (\s1 s2 -> owlTree_superOwl_comparePosition (_owlPFState_owlTree pfs) s2 s1) selectedsowls']
    -- otherwise select everything
    else selectedsowls'

  r = makeSortedSuperOwlParliament (_owlPFState_owlTree pfs) $ Seq.fromList selectedsowls


data SelectHandler = SelectHandler {
    _selectHandler_selectArea :: LBox
  }

instance Default SelectHandler where
  def = SelectHandler {
      _selectHandler_selectArea = LBox 0 0
    }

instance PotatoHandler SelectHandler where
  pHandlerName _ = handlerName_select
  pHandleMouse sh phi@PotatoHandlerInput {..} rmd@(RelMouseDrag MouseDrag {..}) = Just $ case _mouseDrag_state of
    MouseDragState_Down -> r where

      nextSelection@(SuperOwlParliament sowls) = selectMagic _potatoHandlerInput_pFState (_layersState_meta _potatoHandlerInput_layersState) _potatoHandlerInput_broadPhase rmd
      -- since selection came from canvas, it's definitely a valid CanvasSelection, no need to convert
      nextCanvasSelection = CanvasSelection sowls
      shiftClick = isJust $ find (==KeyModifier_Shift) _mouseDrag_modifiers

      r = if isParliament_null nextSelection || shiftClick
        then captureWithNoChange sh

        -- special select+drag case, override the selection
        -- NOTE BoxHandler here is used to move all SElt types, upon release, it will either return the correct handler type or not capture the input in which case Goat will set the correct handler type
        else case pHandleMouse (def { _boxHandler_creation = BoxCreationType_DragSelect }) (phi { _potatoHandlerInput_selection = nextSelection, _potatoHandlerInput_canvasSelection = nextCanvasSelection }) rmd of
          -- force the selection from outside the handler and ignore the new selection results returned by pho (which should always be Nothing)
          Just pho -> assert (isNothing . _potatoHandlerOutput_select $ pho)
            $ pho { _potatoHandlerOutput_select = Just (False, nextSelection) }
          Nothing -> error "handler was expected to capture this mouse state"


    MouseDragState_Dragging -> setHandlerOnly sh {
        _selectHandler_selectArea = selectBoxFromRelMouseDrag rmd
      }
    MouseDragState_Up -> def { _potatoHandlerOutput_select = Just (shiftClick, newSelection) }  where
      shiftClick = isJust $ find (==KeyModifier_Shift) (_mouseDrag_modifiers)
      newSelection = selectMagic _potatoHandlerInput_pFState (_layersState_meta _potatoHandlerInput_layersState) _potatoHandlerInput_broadPhase rmd
    MouseDragState_Cancelled -> def
  pHandleKeyboard _ PotatoHandlerInput {..} _ = Nothing
  pRenderHandler sh PotatoHandlerInput {..} = HandlerRenderOutput (fmap defaultRenderHandle $ substract_lBox full inside) where
    full@(LBox (V2 x y) (V2 w h)) = _selectHandler_selectArea sh
    inside = if w > 2 && h > 2
      then LBox (V2 (x+1) (y+1)) (V2 (w-2) (h-2))
      else LBox 0 0
  pIsHandlerActive _ = True
  pHandlerTool _ = Just Tool_Select
