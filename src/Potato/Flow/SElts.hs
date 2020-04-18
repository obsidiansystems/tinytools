module Potato.Flow.SElts (
  PChar
  , SLineStyle(..)
  , STextStyle(..)
  , SBox(..)
  , SLine(..)
  , SText(..)
  , SElt(..)
  , SEltLabel(..)
  , SEltTree
) where

import           Relude

import           Potato.Flow.Math

import           Data.Aeson

type PChar = Char

data SLineStyle = SLineStyle {
  sbs_corners      :: PChar
  , sbs_vertical   :: PChar
  , sbs_horizontal :: PChar
} deriving (Eq, Generic, Show)

instance FromJSON SLineStyle
instance ToJSON SLineStyle

data STextStyle = STextStyle {
  -- margins
} deriving (Eq, Generic, Show)

instance FromJSON STextStyle
instance ToJSON STextStyle

-- | serializable representations of each type of Elt
data SBox = SBox {
  sb_box     :: LBox
  , sb_style :: SLineStyle
} deriving (Eq, Generic, Show)

instance FromJSON SBox
instance ToJSON SBox

-- |
data SLine = SLine {
  sl_start   :: LPoint
  , sl_ends  :: NonEmpty (Either X Y)
  , sl_style :: SLineStyle
} deriving (Eq, Generic, Show)

instance FromJSON SLine
instance ToJSON SLine

-- | abitrary text confined to a box
data SText = SText {
  st_box     :: LBox
  , st_text  :: Text
  , st_style :: STextStyle
} deriving (Eq, Generic, Show)

instance FromJSON SText
instance ToJSON SText

data SElt = SEltNone | SEltFolderStart | SEltFolderEnd | SEltBox SBox | SEltLine SLine | SEltText SText deriving (Eq, Generic, Show)

instance FromJSON SElt
instance ToJSON SElt

data SEltLabel = SEltLabel {
 selt_name  :: Text
 , selt_elt :: SElt
} deriving (Generic, Show)

instance FromJSON SEltLabel
instance ToJSON SEltLabel

-- expected to satisfy scoping invariant
type SEltTree = [SEltLabel]
