module Potato.Flow.OwlSpec (
  spec
) where


import           Relude

import           Test.Hspec

import qualified Data.Sequence            as Seq
import qualified Data.IntSet as IS
import qualified Data.IntMap as IM
import           Potato.Flow.OwlItem
import Potato.Flow.Owl
import           Potato.Flow.Deprecated.TestStates
import           Potato.Flow.Deprecated.State
import Potato.Flow.Types
import Potato.Flow.SElts


-- | 'owlTree_toSEltTree' may change SEltFolderEnd name and REltId during reconstruction
-- so we simply filter it out so we can compare the parts that should not have changed
filterFolderEndFn :: (REltId, SEltLabel) -> Bool
filterFolderEndFn (_, SEltLabel _ SEltFolderEnd) = False
filterFolderEndFn _ = True

spec :: Spec
spec = do
  describe "Owl" $ do
    let
      owlTree0 = owlTree_fromOldState (_pFState_directory pfstate_basic2) (_pFState_layers pfstate_basic2)
      owlMapping0 = _owlTree_mapping owlTree0
    describe "OwlMapping" $ do
      it "isDescendentOf" $ do
        isDescendentOf owlMapping0 1 2 `shouldBe` True
        isDescendentOf owlMapping0 0 2 `shouldBe` True
        isDescendentOf owlMapping0 2 1 `shouldBe` False -- 2 is child of 1
        isDescendentOf owlMapping0 1 7 `shouldBe` False -- siblings

    describe "OwlTree" $ do
      let
        sEltTree2 = _sPotatoFlow_sEltTree (pFState_to_sPotatoFlow pfstate_basic2)
      it "owlTree_validate" $ do
        --putTextLn $ show $ owlTree_validate owlTree0
        fst (owlTree_validate owlTree0) `shouldBe` True
      it "owlTree_fromOldState" $ do
        --forM (potatoShow owlTree0) print
        (Seq.length (owlTree_topSuperOwls owlTree0) `shouldBe` 1)
        owlTree_owlCount owlTree0 `shouldBe` 9
      it "owliterateall" $ do
        toList (fmap _superOwl_id (owliterateall owlTree0)) `shouldBe` [0,1,2,3,4,5,7,8,9]
      it "owlTree_toSEltTree" $ do
        filter filterFolderEndFn (owlTree_toSEltTree owlTree0) `shouldBe` filter filterFolderEndFn sEltTree2
      it "owlTree_removeSuperOwl" $ do
        let
          sowl1 = owlTree_mustFindSuperOwl owlTree0 2 -- b1
          sowl2 = owlTree_mustFindSuperOwl owlTree0 1 -- fstart2
          ot1 = owlTree_removeSuperOwl sowl1 owlTree0
          ot2 = owlTree_removeSuperOwl sowl2 owlTree0
        owlTree_owlCount ot1 `shouldBe` 8
        owlTree_owlCount ot2 `shouldBe` 4
        fst (owlTree_validate ot1) `shouldBe` True
        fst (owlTree_validate ot2) `shouldBe` True
      it "owlTree_addOwlItem" $ do
        let
          owlSpot1 = OwlSpot (-1) Nothing
          owlItem1 = OwlItem (OwlInfo "💩") OwlSubItemNone
          rid = owlTree_maxId owlTree0 + 1
          owlSpot2 = OwlSpot 7 (Just 9)
          (ot1, _) = owlTree_addOwlItem owlSpot1 rid owlItem1 owlTree0
          (ot2, _) = owlTree_addOwlItem owlSpot2 rid owlItem1 owlTree0
        owlTree_owlCount ot1 `shouldBe` 10
        owlTree_owlCount ot2 `shouldBe` 10
        fst (owlTree_validate ot1) `shouldBe` True
        fst (owlTree_validate ot2) `shouldBe` True
        -- too lazy to write proper test, just print and verify manually
        --putTextLn (potatoShow $ owlTree_addOwlItem owlSpot2 rid owlItem1 owlTree0)
      it "owlTree_moveOwlParliament" $ do
        let
          owlSpot1 = OwlSpot (-1) Nothing
          parliament = OwlParliament $ Seq.fromList [2,3,7]
          (ot1, c1) = owlTree_moveOwlParliament parliament owlSpot1 owlTree0
        owlTree_owlCount ot1 `shouldBe` 9
        -- 5 becaues this includes the 2 children of 7
        length c1 `shouldBe` 5
        fst (owlTree_validate ot1) `shouldBe` True
        -- too lazy to write proper test, just print and verify manually
        --putTextLn (potatoShow . fst $ owlTree_moveOwlParliament parliament owlSpot1 owlTree0)
      it "owlTree_addSEltTree" $ do
        let
          owlSpot1 = OwlSpot (-1) Nothing
          -- current version of owlTree_addSEltTree requires non-colliding REltIds so we reindex here
          seltree1 = fmap (\(rid,seltl) -> (rid+100, seltl)) $ owlTree_toSEltTree owlTree0
          (ot1, c1) = owlTree_addSEltTree owlSpot1 seltree1 owlTree0
        owlTree_owlCount ot1 `shouldBe` 18
        length c1 `shouldBe` 9
        fst (owlTree_validate ot1) `shouldBe` True
      it "owlTree_equivalent" $ do
        owlTree_equivalent owlTree0 owlTree0 `shouldBe` True
      it "owlTree_findSuperOwlAtOwlSpot" $ do
        let
          b2sowl = owlTree_mustFindSuperOwl owlTree0 2
        owlTree_findSuperOwlAtOwlSpot owlTree0 (owlTree_owlItemMeta_toOwlSpot owlTree0 (_superOwl_meta $ b2sowl)) `shouldBe` Just b2sowl

      let
        owlTreeWithAttachments0 = owlTree_fromOldState (_pFState_directory pfstate_attachments1) (_pFState_layers pfstate_attachments1)
        am0 = owlTree_makeAttachmentMap owlTreeWithAttachments0
      it "owlTree_makeAttachmentMap" $ do
        liftIO $ print am0
        IM.lookup 0 am0 `shouldBe` (Just $ IS.fromList [4])
        IM.lookup 2 am0 `shouldBe` (Just $ IS.fromList [4,5])
        IM.lookup 3 am0 `shouldBe` (Just $ IS.fromList [5])
      it "owlTree_hasDanglingAttachments" $ do
        owlTree_hasDanglingAttachments owlTreeWithAttachments0 `shouldBe` False
        owlTree_hasDanglingAttachments (owlTree_reindex 100 owlTreeWithAttachments0) `shouldBe` False
    describe "OwlParliament" $ do
      it "superOwlParliament_isValid" $ do
        --putTextLn (potatoShow owlTree0)
        let
          validParliament = owlParliament_toSuperOwlParliament owlTree0 (OwlParliament $ Seq.fromList [2,3,7])
          invalidParliament = owlParliament_toSuperOwlParliament owlTree0 (OwlParliament $ Seq.fromList [2,3,7,9])
        superOwlParliament_isValid owlTree0 validParliament `shouldBe` True
        superOwlParliament_isValid owlTree0 invalidParliament `shouldBe` False
      it "superOwlParliament_disjointUnionAndCorrect" $ do
        let
          tosop = SuperOwlParliament . Seq.fromList . fmap (owlTree_mustFindSuperOwl owlTree0)
          torids (SuperOwlParliament sop) = toList $ fmap _superOwl_id sop
          sopnil = tosop []
          sop0 = tosop [0]
          sop1 = tosop [1]
          sop2 = tosop [2]
          sop3 = tosop [3]
          sop7 = tosop [7]
          sop8 = tosop [8]
          sop9 = tosop [9]
          sop89 = tosop [8,9]
          sop28 = tosop [2,8]
        torids (superOwlParliament_disjointUnionAndCorrect owlTree0 sopnil sopnil) `shouldBe` []
        torids (superOwlParliament_disjointUnionAndCorrect owlTree0 sopnil sop1) `shouldBe` [1]
        torids (superOwlParliament_disjointUnionAndCorrect owlTree0 sop1 sop1) `shouldBe` []
        torids (superOwlParliament_disjointUnionAndCorrect owlTree0 sop2 sop3) `shouldBe` [2,3]
        torids (superOwlParliament_disjointUnionAndCorrect owlTree0 sop1 sop2) `shouldBe` [3,4,5]
        torids (superOwlParliament_disjointUnionAndCorrect owlTree0 sop1 sop2) `shouldBe` [3,4,5]
        torids (superOwlParliament_disjointUnionAndCorrect owlTree0 sop1 sop28) `shouldBe` [3,4,5,8]
        torids (superOwlParliament_disjointUnionAndCorrect owlTree0 sop0 sop28) `shouldBe` [3,4,5,9]
        torids (superOwlParliament_disjointUnionAndCorrect owlTree0 sop7 sop8) `shouldBe` [9]
        torids (superOwlParliament_disjointUnionAndCorrect owlTree0 sop7 sop9) `shouldBe` [8]
        torids (superOwlParliament_disjointUnionAndCorrect owlTree0 sop89 sop7) `shouldBe` [7]
        torids (superOwlParliament_disjointUnionAndCorrect owlTree0 sop28 sop0) `shouldBe` [0]
      it "owlParliament_convertToMiniOwltree" $ do
        let
          mot = owlParliament_convertToMiniOwltree owlTree0 (OwlParliament (_owlTree_topOwls owlTree0))
        --putTextLn (potatoShow mot)
        -- also tests owlTree_equivalent :D
        owlTree_equivalent mot owlTree0 `shouldBe` True
        owlTree_equivalent owlTree0 mot `shouldBe` True
