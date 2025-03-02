-- DEPRECATED
-- keeping around because we use the types for testing

{-# LANGUAGE RecordWildCards #-}
{-# OPTIONS_GHC -fno-warn-type-defaults #-}
module Potato.Flow.Deprecated.TestStates (
  folderStart
  , folderEnd
  , someSEltLabel
  , someSCanvas
  , defaultCanvasLBox
  , pFState_fromSElts
  , pfstate_someValidState1
  , pfstate_someInvalidState1
  , pfstate_someInvalidState2
  , pfstate_basic0
  , pfstate_basic1
  , pfstate_basic2
  , pfstate_attachments1
  , pfstate_attachments2
  , pfstate_zero
) where

import           Relude

import           Data.Default
import qualified Data.IntMap   as IM
import qualified Data.Sequence as Seq
import           Potato.Flow
import           Potato.Flow.Deprecated.State
--import           Potato.Flow.OwlItem
import Potato.Flow.OwlState
--import           Potato.Flow.OwlItem
import Potato.Flow.Owl

folderStart :: SEltLabel
folderStart = SEltLabel "folder" SEltFolderStart

folderEnd :: SEltLabel
folderEnd = SEltLabel "folder (end)" SEltFolderEnd

someSEltLabel :: SEltLabel
someSEltLabel = SEltLabel "some elt" SEltNone

defaultCanvasLBox :: LBox
defaultCanvasLBox = LBox (V2 0 0) (V2 50 25)

someSCanvas :: SCanvas
someSCanvas = SCanvas  defaultCanvasLBox

pFState_fromSElts :: [SElt] -> LBox -> PFState
pFState_fromSElts selts lbox = PFState {
    _pFState_layers = Seq.fromList [1..length selts]
    , _pFState_directory = IM.fromList $ fmap (\(i,selt) -> (i, SEltLabel (show i) selt)) $ zip [1..] selts
    , _pFState_canvas = SCanvas lbox
  }

pfstate_someValidState1 :: PFState
pfstate_someValidState1 = PFState {
      _pFState_layers = Seq.fromList [0..5]
      , _pFState_directory = IM.fromList [(0, folderStart), (1, folderEnd), (2, someSEltLabel), (3, someSEltLabel), (4, someSEltLabel), (5, someSEltLabel)]
      , _pFState_canvas = SCanvas defaultCanvasLBox
  }

pfstate_someInvalidState1 :: PFState
pfstate_someInvalidState1 = PFState {
      _pFState_layers = Seq.fromList [0..5]
      -- missing REltId 5
      , _pFState_directory = IM.fromList [(0, folderStart), (1, folderEnd), (2, someSEltLabel), (3, someSEltLabel), (4, someSEltLabel)]
      , _pFState_canvas = SCanvas defaultCanvasLBox
  }

pfstate_someInvalidState2 :: PFState
pfstate_someInvalidState2 = PFState {
      -- folder mismatch
      _pFState_layers = Seq.fromList [0..5]
      , _pFState_directory = IM.fromList [(0, folderStart), (1, folderStart), (2, someSEltLabel), (3, someSEltLabel), (4, someSEltLabel)]
      , _pFState_canvas = SCanvas defaultCanvasLBox
  }

pfstate_basic0 :: PFState
pfstate_basic0 = PFState {
    _pFState_layers = Seq.fromList [0..2]
    , _pFState_directory = IM.fromList [
        (0, SEltLabel "box" (SEltBox def {
            _sBox_box = LBox (V2 1 1) (V2 5 5)
          }))
        , (1, SEltLabel "line" (SEltLine def {
            _sAutoLine_start = V2 7 2
            , _sAutoLine_end = V2 20 18
          }))
        , (2, SEltLabel "text" (SEltBox def {
            _sBox_box = LBox (V2 0 10) (V2 15 5)
            , _sBox_boxType = SBoxType_NoBoxText
          }))
      ]
    , _pFState_canvas = SCanvas defaultCanvasLBox
  }

pfstate_basic1 :: PFState
pfstate_basic1 = PFState {
    _pFState_layers = Seq.fromList [0..5]
    , _pFState_directory = IM.fromList [
        -- 4 boxes in a grid
        (0, SEltLabel "b1" (SEltBox def {
            _sBox_box = LBox (V2 0 0) (V2 5 5)
          }))
        , (1, SEltLabel "b2" (SEltBox def {
            _sBox_box = LBox (V2 10 10) (V2 5 5)
          }))
        , (2, SEltLabel "b3" (SEltBox def {
            _sBox_box = LBox (V2 0 10) (V2 5 5)
          }))
        , (3, SEltLabel "b4" (SEltBox def {
            _sBox_box = LBox (V2 10 0) (V2 5 5)
          }))

        -- 2 lines sharing a start point at (0,100)
        , (4, SEltLabel "sl1" (SEltLine def {
            _sAutoLine_start = V2 0 100
            , _sAutoLine_end = V2 0 110
          }))
        , (5, SEltLabel "sl2" (SEltLine def {
            _sAutoLine_start = V2 0 100
            , _sAutoLine_end = V2 10 100
          }))

      ]
    , _pFState_canvas = SCanvas defaultCanvasLBox
  }

-- | same as pfstate_basic1 except with folders
pfstate_basic2 :: PFState
pfstate_basic2 = PFState {
    _pFState_layers = Seq.fromList [0..11]
    , _pFState_directory = IM.fromList [
        (0, SEltLabel "fstart1" SEltFolderStart)
          , (1, SEltLabel "fstart2" SEltFolderStart)
            -- 4 boxes in a grid
            , (2, SEltLabel "b1" (SEltBox def {
                _sBox_box = LBox (V2 0 0) (V2 5 5)
              }))
            , (3, SEltLabel "b2" (SEltBox def {
                _sBox_box = LBox (V2 10 10) (V2 5 5)
              }))
            , (4, SEltLabel "b3" (SEltBox def {
                _sBox_box = LBox (V2 0 10) (V2 5 5)
              }))
            , (5, SEltLabel "b4" (SEltBox def {
                _sBox_box = LBox (V2 10 0) (V2 5 5)
              }))
            , (6, SEltLabel "fend2" SEltFolderEnd)
        , (7, SEltLabel "fstart3" SEltFolderStart)
          -- 2 lines sharing a start point at (0,100)
          , (8, SEltLabel "sl1" (SEltLine def {
              _sAutoLine_start = V2 0 100
              , _sAutoLine_end = V2 0 110
            }))
          , (9, SEltLabel "sl2" (SEltLine def {
              _sAutoLine_start = V2 0 100
              , _sAutoLine_end = V2 10 100
            }))
          , (10, SEltLabel "fend3" SEltFolderEnd)
        , (11, SEltLabel "fend1" SEltFolderEnd)
      ]
    , _pFState_canvas = SCanvas defaultCanvasLBox
  }

pfstate_attachments1 :: PFState
pfstate_attachments1 = PFState {
    _pFState_layers = Seq.fromList [0..5]
    , _pFState_directory = IM.fromList [
      -- 4 boxes in a grid
      (0, SEltLabel "b1" (SEltBox def {
          _sBox_box = LBox (V2 0 0) (V2 5 5)
        }))
      , (1, SEltLabel "b2" (SEltBox def {
          _sBox_box = LBox (V2 10 10) (V2 5 5)
        }))
      , (2, SEltLabel "b3" (SEltBox def {
          _sBox_box = LBox (V2 0 10) (V2 5 5)
        }))
      , (3, SEltLabel "b4" (SEltBox def {
          _sBox_box = LBox (V2 10 0) (V2 5 5)
        }))

      -- 2 lines sharing a start point at (0,100)
      , (4, SEltLabel "b1-> <-b3" (SEltLine def {
          _sAutoLine_start = V2 0 100
          , _sAutoLine_end = V2 0 110
          , _sAutoLine_attachStart = Just (Attachment {
              _attachment_target = 0
              , _attachment_location = AL_Right
            })
          , _sAutoLine_attachEnd = Just (Attachment {
              _attachment_target = 2
              , _attachment_location = AL_Left
            })
        }))
      , (5, SEltLabel "b2v ^b4" (SEltLine def {
          _sAutoLine_start = V2 0 100
          , _sAutoLine_end = V2 0 110
          , _sAutoLine_attachStart = Just (Attachment {
              _attachment_target = 2
              , _attachment_location = AL_Bot
            })

          , _sAutoLine_attachEnd = Just (Attachment {
              _attachment_target = 3
              , _attachment_location = AL_Top
            })
        }))
      ]
    , _pFState_canvas = SCanvas defaultCanvasLBox
  }

-- TODO DELETE ME
pfstate_attachments2 :: PFState
pfstate_attachments2 = PFState {
    _pFState_layers = Seq.fromList [0..9]
    , _pFState_directory = IM.fromList [
      -- 4 boxes in a grid
      (0, SEltLabel "b1" (SEltBox def {
          _sBox_box = LBox (V2 0 0) (V2 5 5)
        }))
      , (1, SEltLabel "b2" (SEltBox def {
          _sBox_box = LBox (V2 10 0) (V2 5 5)
        }))
      , (2, SEltLabel "b3" (SEltBox def {
          _sBox_box = LBox (V2 0 10) (V2 5 5)
        }))
      , (3, SEltLabel "b4" (SEltBox def {
          _sBox_box = LBox (V2 10 10) (V2 5 5)
        }))



      -- 2 lines sharing a start point at (0,100)
      , (4, SEltLabel "b1-> <-b4" (SEltLine def {
          _sAutoLine_start = V2 0 100
          , _sAutoLine_end = V2 0 110
          , _sAutoLine_attachStart = Just (Attachment {
              _attachment_target = 0
              , _attachment_location = AL_Right
            })
          , _sAutoLine_attachEnd = Just (Attachment {
              _attachment_target = 3
              , _attachment_location = AL_Left
            })
        }))
      , (5, SEltLabel "<-b1 b2->" (SEltLine def {
          _sAutoLine_start = V2 0 100
          , _sAutoLine_end = V2 0 110
          , _sAutoLine_attachStart = Just (Attachment {
              _attachment_target = 0
              , _attachment_location = AL_Left
            })

          , _sAutoLine_attachEnd = Just (Attachment {
              _attachment_target = 1
              , _attachment_location = AL_Right
            })
        }))
      , (6, SEltLabel "<-b1 b4->" (SEltLine def {
          _sAutoLine_start = V2 0 100
          , _sAutoLine_end = V2 0 110
          , _sAutoLine_attachStart = Just (Attachment {
              _attachment_target = 0
              , _attachment_location = AL_Left
            })

          , _sAutoLine_attachEnd = Just (Attachment {
              _attachment_target = 3
              , _attachment_location = AL_Right
            })
        }))
      , (7, SEltLabel "b1-> b4->" (SEltLine def {
          _sAutoLine_start = V2 0 100
          , _sAutoLine_end = V2 0 110
          , _sAutoLine_attachStart = Just (Attachment {
              _attachment_target = 0
              , _attachment_location = AL_Right
            })

          , _sAutoLine_attachEnd = Just (Attachment {
              _attachment_target = 3
              , _attachment_location = AL_Right
            })
        }))
        , (8, SEltLabel "b1-> b2->" (SEltLine def {
            _sAutoLine_start = V2 0 100
            , _sAutoLine_end = V2 0 110
            , _sAutoLine_attachStart = Just (Attachment {
                _attachment_target = 0
                , _attachment_location = AL_Right
              })

            , _sAutoLine_attachEnd = Just (Attachment {
                _attachment_target = 1
                , _attachment_location = AL_Right
              })
          }))
      , (9, SEltLabel "b1v ^b3" (SEltLine def {
          _sAutoLine_start = V2 0 100
          , _sAutoLine_end = V2 0 110
          , _sAutoLine_attachStart = Just (Attachment {
              _attachment_target = 0
              , _attachment_location = AL_Bot
            })

          , _sAutoLine_attachEnd = Just (Attachment {
              _attachment_target = 2
              , _attachment_location = AL_Top
            })
        }))
      ]
    , _pFState_canvas = SCanvas defaultCanvasLBox
  }


-- contains SElts of size 0
pfstate_zero :: PFState
pfstate_zero = PFState {
    _pFState_layers = Seq.fromList [0..1]
    , _pFState_directory = IM.fromList [
        (0, SEltLabel "b1" (SEltBox def {
            _sBox_box = LBox (V2 0 0) (V2 0 0)
          }))
        , (1, SEltLabel "sl1" (SEltLine def {
            _sAutoLine_start = V2 10 10
            , _sAutoLine_end = V2 10 10
          }))
      ]
    , _pFState_canvas = SCanvas defaultCanvasLBox
  }
