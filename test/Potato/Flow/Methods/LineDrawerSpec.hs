{-# LANGUAGE RecordWildCards #-}

module Potato.Flow.Methods.LineDrawerSpec(
  spec
) where

import           Relude           hiding (empty, fromList)

import           Test.Hspec


import Potato.Flow
import           Potato.Flow.Methods.LineDrawer

import Data.Default

generateTestCases :: [OwlPFState]
generateTestCases = r where

  -- MODIFY THESE TO TEST WHAT YOU NEED TO TEST :O
  al1s = [AL_Left, AL_Right, AL_Top, AL_Bot, AL_Any]
  al2s = [AL_Left, AL_Right, AL_Top, AL_Bot, AL_Any]
  --al1s = [AL_Top]
  --al2s = [AL_Bot]
  box1s = [LBox (V2 0 10) 5]
  box2s = [LBox (V2 5 8) 3]
  canvasbox = LBox (-5) (V2 25 25)


  boxpairs = [(b1,b2) | b1 <- box1s, b2 <- box2s]
  attachmentpairs = [(al1,al2) | al1 <- al1s, al2 <- al2s]



  makestree (b1,b2) (al1, al2) =
    [ (0, SEltLabel "b1" (SEltBox (def {_sBox_box = b1})))
    , (1, SEltLabel "b2" (SEltBox (def {_sBox_box = b2})))
    , (2, SEltLabel "l" (SEltLine (def {_sAutoLine_attachStart = Just (Attachment 0 al1), _sAutoLine_attachEnd = Just (Attachment 1 al2)})))
    --, (3, SEltLabel "lreverse" (SEltLine (def {_sAutoLine_attachStart = Just (Attachment 1 al2), _sAutoLine_attachEnd = Just (Attachment 0 al1)})))
    ]

  topfs ot = OwlPFState {
      _owlPFState_owlTree = ot
      , _owlPFState_canvas = SCanvas $ canvasbox
    }

  r = [topfs $ owlTree_fromSEltTree (makestree bp ap) | bp <- boxpairs, ap <- attachmentpairs]


validateTransformMe :: (Eq a, TransformMe a) => a -> Bool
validateTransformMe a =
  (transformMe_rotateLeft . transformMe_rotateRight $ a) == a
  && (transformMe_rotateRight . transformMe_rotateLeft $ a) == a
  && (transformMe_reflectHorizontally . transformMe_reflectHorizontally $ a) == a

spec :: Spec
spec = do
  describe "Lines - internal" $ do
    it "rotateMe" $ do
      let
        somelbx1 = LBox (V2 12 (-2)) (V2 12323 (143))
        somexy1 :: XY = V2 345 21
      validateTransformMe somelbx1 `shouldBe` True
      validateTransformMe somexy1 `shouldBe` True
    it "determineSeparation" $ do
      let
        lb1 = LBox (V2 0 0) (V2 10 10)
        lb2 = LBox (V2 11 11) (V2 10 10)
      determineSeparation (lb1, (0,0,0,0)) (lb2, (0,0,0,0)) `shouldBe` (True, True)
      determineSeparation (lb1, (2,2,0,0)) (lb2, (0,0,0,0)) `shouldBe` (False, True)
      determineSeparation (lb1, (1,1,1,1)) (lb2, (1,1,1,1)) `shouldBe` (False, False)
    it "lineAnchorsForRender_simplify" $ do
      let
        lineanchors = LineAnchorsForRender {
            _lineAnchorsForRender_start = 0
            , _lineAnchorsForRender_rest = [(CD_Up, 10, True),(CD_Up, 15, False),(CD_Up, 1, False),(CD_Right, 10, False)]
          }
      _lineAnchorsForRender_rest (lineAnchorsForRender_simplify lineanchors) `shouldBe` [(CD_Up, 26, True),(CD_Right, 10, False)]
  describe "Lines - rendering" $ it "autorendercase" $ forM_ generateTestCases $ \pfs -> do
    --putTextLn (renderedCanvasToText (potatoRenderPFState pfs))
    True `shouldBe` True

    -- TODO write a test such that reversing start/end parts of lines always renders the same thing
    -- (actually, this won't work because rotation messed with whether we go up/down for midpoint stuff)
    -- (you could fix this by keeping a rotation counter flag of course)
