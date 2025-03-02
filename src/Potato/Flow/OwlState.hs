{-# LANGUAGE RecordWildCards #-}

module Potato.Flow.OwlState where

import           Relude

import Potato.Flow.Owl
import Potato.Flow.Attachments
import Potato.Flow.OwlItem
import           Potato.Flow.Math
import           Potato.Flow.SElts
import           Potato.Flow.SEltMethods
import           Potato.Flow.Types
import Potato.Flow.DebugHelpers

import           Control.Exception       (assert)
import qualified Data.IntMap.Strict      as IM
import           Data.List.Ordered       (isSortedBy)
import           Data.Maybe
import qualified Data.Text as T


-- prob not the best place for these...
maybeGetAttachmentPosition :: Bool -> OwlPFState -> Attachment -> Maybe XY
maybeGetAttachmentPosition offsetBorder pfs a = do
  target <- hasOwlTree_findSuperOwl pfs (_attachment_target a)
  return $ case hasOwlItem_owlItem target of
    OwlItem _ (OwlSubItemBox sbox) -> attachLocationFromLBox offsetBorder (_sBox_box sbox) (_attachment_location a)
    _ -> error "expecteed OwlSubItemBox"

maybeLookupAttachment :: Bool -> OwlPFState -> Maybe Attachment -> Maybe XY
maybeLookupAttachment offsetBorder pfs matt = maybeGetAttachmentPosition offsetBorder pfs =<< matt



-- TODO rename
data OwlPFState = OwlPFState {
  _owlPFState_owlTree :: OwlTree
  , _owlPFState_canvas    :: SCanvas
} deriving (Show, Eq, Generic)

instance HasOwlTree OwlPFState where
  hasOwlTree_owlTree = _owlPFState_owlTree

-- TODO delete replace with PotatoShow
owlPFState_prettyPrintForDebugging :: OwlPFState -> Text
owlPFState_prettyPrintForDebugging OwlPFState {..} = potatoShow _owlPFState_owlTree <> show _owlPFState_canvas

instance PotatoShow OwlPFState where
  potatoShow = owlPFState_prettyPrintForDebugging

instance NFData OwlPFState

owlPFState_nextId :: OwlPFState -> REltId
owlPFState_nextId pfs = (+1) . owlTree_maxId . _owlPFState_owlTree $ pfs

owlPFState_lastId :: OwlPFState -> REltId
owlPFState_lastId pfs = owlTree_maxId . _owlPFState_owlTree $ pfs

owlPFState_numElts :: OwlPFState -> Int
owlPFState_numElts pfs = IM.size . _owlTree_mapping . _owlPFState_owlTree $ pfs

-- TODO DELETE replace with potatoShow
debugPrintOwlPFState :: (IsString a) => OwlPFState -> a
debugPrintOwlPFState OwlPFState {..} = fromString . T.unpack $ potatoShow _owlPFState_owlTree

-- TODO owlPFState_selectionIsValid pfs OwlParliament $ Seq.fromList [0..Seq.length _owlPFState_layers - 1]
owlPFState_isValid :: OwlPFState -> Bool
owlPFState_isValid OwlPFState {..} = True

owlPFState_selectionIsValid :: OwlPFState -> OwlParliament -> Bool
owlPFState_selectionIsValid OwlPFState {..} (OwlParliament op) = validElts where
  OwlTree {..} = _owlPFState_owlTree
  validElts = all isJust . toList $ fmap ((IM.!?) _owlTree_mapping) op

-- TODO replace with superOwlParliament_toSEltTree
owlPFState_copyElts :: OwlPFState -> OwlParliament -> [SEltLabel]
owlPFState_copyElts OwlPFState {..} op = r where
  sop = owlParliament_toSuperOwlParliament _owlPFState_owlTree op
  r = fmap snd $ superOwlParliament_toSEltTree _owlPFState_owlTree sop

-- TODO replace with owlTree_findSuperOwl
owlPFState_getSuperOwls :: OwlPFState -> [REltId] -> REltIdMap (Maybe SuperOwl)
owlPFState_getSuperOwls OwlPFState {..} rids = foldr (\rid acc -> IM.insert rid (owlTree_findSuperOwl _owlPFState_owlTree rid) acc) IM.empty rids

emptyOwlPFState :: OwlPFState
emptyOwlPFState = OwlPFState emptyOwlTree (SCanvas (LBox 0 1))

sPotatoFlow_to_owlPFState :: SPotatoFlow -> OwlPFState
sPotatoFlow_to_owlPFState SPotatoFlow {..} = r where
  r = OwlPFState (owlTree_fromSEltTree _sPotatoFlow_sEltTree) _sPotatoFlow_sCanvas

owlPFState_to_sPotatoFlow :: OwlPFState -> SPotatoFlow
owlPFState_to_sPotatoFlow OwlPFState {..} = r where
  selttree = owlTree_toSEltTree _owlPFState_owlTree
  r = SPotatoFlow _owlPFState_canvas selttree

owlPFState_toCanvasCoordinates :: OwlPFState -> XY -> XY
owlPFState_toCanvasCoordinates OwlPFState {..} (V2 x y) = V2 (x-sx) (y-sy) where
  LBox (V2 sx sy) _ = _sCanvas_box _owlPFState_canvas

owlPFState_to_SuperOwlParliament :: OwlPFState -> SuperOwlParliament
owlPFState_to_SuperOwlParliament OwlPFState {..} = owlParliament_toSuperOwlParliament _owlPFState_owlTree $ OwlParliament $ _owlTree_topOwls _owlPFState_owlTree

do_newElts :: [(REltId, OwlSpot, OwlItem)] -> OwlPFState -> (OwlPFState, SuperOwlChanges)
do_newElts seltls pfs@OwlPFState {..} = r where

  -- parents are allowed, but seltls must be sortefd from left -> right such that leftmost sibling/parent of OwlSpot exists (assuming elts are added to the tree from left to right)
  (newot, changes') = owlTree_addOwlItemList seltls _owlPFState_owlTree

  changes = IM.fromList $ fmap (\sowl -> (_superOwl_id sowl, Just sowl)) changes'
  r = (pfs { _owlPFState_owlTree = newot}, changes)

undo_newElts :: [(REltId, OwlSpot, OwlItem)] -> OwlPFState -> (OwlPFState, SuperOwlChanges)
undo_newElts seltls pfs@OwlPFState {..} = r where
  foldfn (rid,_,_) od = owlTree_removeREltId rid od
  -- assumes seltls sorted from left to right so that no parent is deleted before its child
  newot = foldr foldfn _owlPFState_owlTree seltls
  changes = IM.fromList $ fmap (\(rid,_,_) -> (rid, Nothing)) seltls
  r = (pfs { _owlPFState_owlTree = newot}, changes)

do_deleteElts :: [(REltId, OwlSpot, OwlItem)] -> OwlPFState -> (OwlPFState, SuperOwlChanges)
do_deleteElts = undo_newElts

undo_deleteElts :: [(REltId, OwlSpot, OwlItem)] -> OwlPFState -> (OwlPFState, SuperOwlChanges)
undo_deleteElts = do_newElts

do_newMiniOwlTree :: (MiniOwlTree, OwlSpot) -> OwlPFState -> (OwlPFState, SuperOwlChanges)
do_newMiniOwlTree (mot, ospot) pfs@OwlPFState {..} = r where
  (newot, changes') = owlTree_addMiniOwlTree ospot mot _owlPFState_owlTree
  changes = IM.fromList $ fmap (\sowl -> (_superOwl_id sowl, Just sowl)) changes'
  r = (pfs { _owlPFState_owlTree = newot}, changes)

undo_newMiniOwlTree :: (MiniOwlTree, OwlSpot) -> OwlPFState -> (OwlPFState, SuperOwlChanges)
undo_newMiniOwlTree (mot, _) pfs@OwlPFState {..} = r where
  foldfn rid od = owlTree_removeREltId rid od
  newot = foldr foldfn _owlPFState_owlTree (_owlTree_topOwls mot)
  changes = IM.fromList $ fmap (\sowl -> (_superOwl_id sowl, Nothing)) $ toList $ owliterateall mot
  r = (pfs { _owlPFState_owlTree = newot}, changes)

do_deleteMiniOwlTree :: (MiniOwlTree, OwlSpot) -> OwlPFState -> (OwlPFState, SuperOwlChanges)
do_deleteMiniOwlTree = undo_newMiniOwlTree

undo_deleteMiniOwlTree :: (MiniOwlTree, OwlSpot) -> OwlPFState -> (OwlPFState, SuperOwlChanges)
undo_deleteMiniOwlTree = do_newMiniOwlTree



isSuperOwlParliamentUndoFriendly :: SuperOwlParliament -> Bool
isSuperOwlParliamentUndoFriendly sop = r where
  rp = _owlItemMeta_position . _superOwl_meta
  sameparent sowl1 sowl2 = _owlItemMeta_parent ( _superOwl_meta sowl1) == _owlItemMeta_parent ( _superOwl_meta sowl2)
  -- this is a hack use of isSortedBy and assumes parliament is ordered correctly
  r = isSortedBy (\sowl1 sowl2 -> if sameparent sowl1 sowl2 then (rp sowl1) < (rp sowl2) else True) . toList . unSuperOwlParliament $ sop

do_move :: (OwlSpot, SuperOwlParliament) -> OwlPFState -> (OwlPFState, SuperOwlChanges)
do_move (os, sop) pfs@OwlPFState {..} = assert isUndoFriendly r where

  -- make sure SuperOwlParliament is ordered in an undo-friendly way
  isUndoFriendly = isSuperOwlParliamentUndoFriendly sop

  op = superOwlParliament_toOwlParliament sop
  (newot, changes') = owlTree_moveOwlParliament op os _owlPFState_owlTree
  changes = IM.fromList $ fmap (\sowl -> (_superOwl_id sowl, Just sowl)) changes'
  r = (pfs { _owlPFState_owlTree = newot}, changes)

undo_move :: (OwlSpot, SuperOwlParliament) -> OwlPFState -> (OwlPFState, SuperOwlChanges)
undo_move (_, sop) pfs@OwlPFState {..} = assert isUndoFriendly r where

  -- NOTE that sop is likely invalid in pfs at this point

  -- make sure SuperOwlParliament is ordered in an undo-friendly way
  isUndoFriendly = isSuperOwlParliamentUndoFriendly sop

  -- first remove all elements we moved
  removefoldfn tree' so = owlTree_removeREltId (_superOwl_id so) tree'
  removedTree = foldl' removefoldfn _owlPFState_owlTree (unSuperOwlParliament sop)

  -- then add them back in in order
  addmapaccumlfn tree' so = owlTree_addOwlItem ospot (_superOwl_id so) (_superOwl_elt so) tree' where
    -- NOTE that because we are ordered from left to right, _superOwl_meta so is valid in tree'
    ospot = owlTree_owlItemMeta_toOwlSpot tree' $ _superOwl_meta so
  (addedTree, changes') = mapAccumL addmapaccumlfn removedTree (unSuperOwlParliament sop)

  changes = IM.fromList $ fmap (\sowl -> (_superOwl_id sowl, Just sowl)) (toList changes')
  r = (pfs { _owlPFState_owlTree = addedTree}, changes)


-- OwlItem compatible variant of updateFnFromController
updateFnFromControllerOwl :: Bool -> Controller -> ((OwlItemMeta, OwlItem)->(OwlItemMeta, OwlItem))
updateFnFromControllerOwl isDo controller = r where
  f = updateFnFromController isDo controller
  -- 😱😱😱
  rewrap oem mkiddos (SEltLabel name elt) = case elt of
    SEltFolderStart -> (oem, OwlItem (OwlInfo name) (OwlSubItemFolder (fromJust mkiddos)))
    s -> (oem, OwlItem (OwlInfo name) (sElt_to_owlSubItem s))
  r (oem, oitem) = case _owlItem_subItem oitem of
    OwlSubItemFolder kiddos -> rewrap oem (Just kiddos) $ f (SEltLabel (owlItem_name oitem) SEltFolderStart)
    _ -> rewrap oem Nothing $ f (hasOwlItem_toSEltLabel_hack oitem)

manipulate :: Bool -> ControllersWithId -> OwlPFState -> (OwlPFState, SuperOwlChanges)
manipulate isDo cs pfs = (r, fmap Just changes) where
  mapping = _owlTree_mapping . _owlPFState_owlTree $ pfs
  changes' = IM.intersectionWith (updateFnFromControllerOwl isDo) cs mapping
  newMapping = IM.union changes' mapping
  changes = IM.mapWithKey (\k (oem, oe) -> SuperOwl k oem oe) changes'
  r = pfs { _owlPFState_owlTree = (_owlPFState_owlTree pfs) { _owlTree_mapping = newMapping } }

do_manipulate :: ControllersWithId -> OwlPFState -> (OwlPFState, SuperOwlChanges)
do_manipulate = manipulate True

undo_manipulate :: ControllersWithId -> OwlPFState -> (OwlPFState, SuperOwlChanges)
undo_manipulate = manipulate False

-- | check if the SCanvas is valid or not
-- for now, canvas offset must always be 0, I forget why it's even an option to offset the SCanvas, probably potatoes.
isValidCanvas :: SCanvas -> Bool
isValidCanvas (SCanvas (LBox p (V2 w h))) = p == 0 && w > 0 && h > 0

do_resizeCanvas :: DeltaLBox -> OwlPFState -> OwlPFState
do_resizeCanvas d pfs = assert (isValidCanvas newCanvas) $ pfs { _owlPFState_canvas = newCanvas } where
  newCanvas = SCanvas $ plusDelta (_sCanvas_box (_owlPFState_canvas pfs)) d

undo_resizeCanvas :: DeltaLBox -> OwlPFState -> OwlPFState
undo_resizeCanvas d pfs = assert (isValidCanvas newCanvas) $ pfs { _owlPFState_canvas = newCanvas } where
  newCanvas = SCanvas $ minusDelta (_sCanvas_box (_owlPFState_canvas pfs)) d
