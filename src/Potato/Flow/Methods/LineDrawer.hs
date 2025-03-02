{-# LANGUAGE RecordWildCards #-}

module Potato.Flow.Methods.LineDrawer (
  LineAnchorsForRender(..)
  , lineAnchorsForRender_doesIntersectPoint
  , lineAnchorsForRender_doesIntersectBox
  , lineAnchorsForRender_findIntersectingSubsegment

  , sAutoLine_to_lineAnchorsForRenders
  , sSimpleLineNewRenderFn
  , sSimpleLineNewRenderFnComputeCache



  -- * exposed for testing
  , CartDir(..)
  , TransformMe(..)
  , determineSeparation
  , lineAnchorsForRender_simplify
) where

import           Relude hiding (tail)
import Relude.Unsafe (tail)

import Potato.Flow.Methods.LineTypes
import           Potato.Flow.Math
import           Potato.Flow.SElts
import Potato.Flow.Methods.Types
import Potato.Flow.Attachments
import Potato.Flow.Owl
import Potato.Flow.OwlItem

import qualified Data.Text          as T
import Data.Tuple.Extra

import Linear.Vector ((^*))

import Control.Exception (assert)

instance TransformMe AttachmentLocation where
  transformMe_rotateLeft = \case
    AL_Top -> AL_Left
    AL_Bot -> AL_Right
    AL_Left -> AL_Bot
    AL_Right -> AL_Top
    AL_Any -> AL_Any
  transformMe_rotateRight = \case
    AL_Top -> AL_Right
    AL_Bot -> AL_Left
    AL_Left -> AL_Top
    AL_Right -> AL_Bot
    AL_Any -> AL_Any
  transformMe_reflectHorizontally = \case
    AL_Left -> AL_Right
    AL_Right -> AL_Left
    x -> x


-- TODO I think you need notion of half separation?
determineSeparation :: (LBox, (Int, Int, Int, Int)) -> (LBox, (Int, Int, Int, Int)) -> (Bool, Bool)
determineSeparation (lbx1, p1) (lbx2, p2) = r where
  (l1,r1,t1,b1) = lBox_to_axis $ lBox_expand lbx1 p1
  (l2,r2,t2,b2) = lBox_to_axis $ lBox_expand lbx2 p2
  hsep = l1 >= r2 || l2 >= r1
  vsep = t1 >= b2 || t2 >= b1
  r = (hsep, vsep)


-- in order to be separated for attachment, there must be space for a line in between the two boxes
-- e.g. both ends are offset by 2 but they only need a space of 3 between them
--   +-*
--   |
-- *-+
determineSeparationForAttachment :: (LBox, (Int, Int, Int, Int)) -> (LBox, (Int, Int, Int, Int)) -> (Bool, Bool)
determineSeparationForAttachment (lbx1, p1) (lbx2, p2) = r where
  (l1,r1,t1,b1) = lBox_to_axis $ lBox_expand lbx1 p1
  (l2,r2,t2,b2) = lBox_to_axis $ lBox_expand lbx2 p2
  hsep = l1 >= r2+1 || l2 >= r1+1
  vsep = t1 >= b2+1 || t2 >= b1+1
  r = (hsep, vsep)

maybeIndex :: Text -> Int -> Maybe MPChar
maybeIndex t i = if i < T.length t
  then Just $ (Just $ T.index t i)
  else Nothing

renderLine :: SuperStyle -> CartDir -> MPChar
renderLine SuperStyle {..} cd = case cd of
  CD_Up -> _superStyle_vertical
  CD_Down -> _superStyle_vertical
  CD_Left -> _superStyle_horizontal
  CD_Right -> _superStyle_horizontal

renderLineEnd :: SuperStyle -> LineStyle -> CartDir -> Int -> MPChar
renderLineEnd SuperStyle {..} LineStyle {..} cd distancefromend = r where
  r = case cd of
    CD_Up -> fromMaybe _superStyle_vertical $ maybeIndex _lineStyle_upArrows distancefromend
    CD_Down -> fromMaybe _superStyle_vertical $ maybeIndex (T.reverse _lineStyle_downArrows) distancefromend
    CD_Left -> fromMaybe _superStyle_horizontal $ maybeIndex _lineStyle_leftArrows distancefromend
    CD_Right -> fromMaybe _superStyle_horizontal $ maybeIndex (T.reverse _lineStyle_rightArrows) distancefromend


renderAnchorType :: SuperStyle -> LineStyle -> AnchorType -> MPChar
renderAnchorType ss@SuperStyle {..} ls at = r where
  r = case at of
    AT_End_Up -> renderLineEnd ss ls CD_Up 0
    AT_End_Down -> renderLineEnd ss ls CD_Down 0
    AT_End_Left -> renderLineEnd ss ls CD_Left 0
    AT_End_Right -> renderLineEnd ss ls CD_Right 0
    AT_Elbow_TL -> _superStyle_tl
    AT_Elbow_TR -> _superStyle_tr
    AT_Elbow_BR -> _superStyle_br
    AT_Elbow_BL -> _superStyle_bl
    AT_Elbow_Invalid -> Just '?'


lineAnchorsForRender_simplify :: LineAnchorsForRender -> LineAnchorsForRender
lineAnchorsForRender_simplify LineAnchorsForRender {..} = r where
  -- remove 0 distance lines except at front and back
  withoutzeros = case _lineAnchorsForRender_rest of
    [] -> []
    x:xs -> x:withoutzerosback xs
    where
      withoutzerosback = \case
        [] -> []
        x:[] -> [x]
        (_, 0, False):xs -> xs
        (_, 0, True):_ -> error "unexpected 0 length subsegment starting anchor"
        x:xs -> x:withoutzerosback xs

  foldrfn (cd, d, s) [] = [(cd, d, s)]
  -- don't double up if next anchor is a subsegment starting anchor (pretty sure this should never happen)
  foldrfn (cd, d, firstisstart) ((cd',d', nextisstart):xs) = if cd == cd' && not nextisstart
    then (cd, d+d', firstisstart):xs
    else (cd,d,firstisstart):(cd',d',nextisstart):xs
  withoutdoubles = foldr foldrfn [] withoutzeros
  r = LineAnchorsForRender {
      _lineAnchorsForRender_start = _lineAnchorsForRender_start
      , _lineAnchorsForRender_rest = withoutdoubles
    }

lineAnchorsForRender_end :: LineAnchorsForRender -> XY
lineAnchorsForRender_end LineAnchorsForRender {..} = foldl' (\p cdd -> p + cartDirWithDistanceToV2 cdd) _lineAnchorsForRender_start _lineAnchorsForRender_rest

lineAnchorsForRender_reverse :: LineAnchorsForRender -> LineAnchorsForRender
lineAnchorsForRender_reverse lafr@LineAnchorsForRender {..} = r where
  end = lineAnchorsForRender_end lafr
  revgo acc [] = acc
  revgo acc ((cd,d,False):[]) = (cd,d,True):acc
  revgo _ ((_,_,True):[]) = error "unexpected subsegment starting anchor at end"
  revgo acc (x:xs) = revgo (x:acc) xs
  revgostart [] = []
  revgostart ((cd,d,True):xs) = revgo [(cd,d,False)] xs
  revgostart _ = error "unexpected non-subsegment starting anchor at start"
  r = LineAnchorsForRender {
      _lineAnchorsForRender_start = end
      , _lineAnchorsForRender_rest = revgostart _lineAnchorsForRender_rest
    }

instance TransformMe LineAnchorsForRender where
  transformMe_rotateLeft LineAnchorsForRender {..} = LineAnchorsForRender {
      _lineAnchorsForRender_start = transformMe_rotateLeft _lineAnchorsForRender_start
      ,_lineAnchorsForRender_rest = fmap (\(cd,d,s) -> (transformMe_rotateLeft cd, d, s)) _lineAnchorsForRender_rest
    }
  transformMe_rotateRight LineAnchorsForRender {..} = LineAnchorsForRender {
      _lineAnchorsForRender_start = transformMe_rotateRight _lineAnchorsForRender_start
      ,_lineAnchorsForRender_rest = fmap (\(cd,d,s) -> (transformMe_rotateRight cd, d, s)) _lineAnchorsForRender_rest
    }
  transformMe_reflectHorizontally LineAnchorsForRender {..} = LineAnchorsForRender {
      _lineAnchorsForRender_start = transformMe_reflectHorizontally _lineAnchorsForRender_start
      ,_lineAnchorsForRender_rest = fmap (\(cd,d,s) -> (transformMe_reflectHorizontally cd, d, s)) _lineAnchorsForRender_rest
    }

lineAnchorsForRender_toPointList :: LineAnchorsForRender -> [XY]
lineAnchorsForRender_toPointList LineAnchorsForRender {..} = r where
  scanlfn pos (cd,d,_) = pos + (cartDirToUnit cd) ^* d
  r = scanl scanlfn _lineAnchorsForRender_start _lineAnchorsForRender_rest

data SimpleLineSolverParameters_NEW = SimpleLineSolverParameters_NEW {
  _simpleLineSolverParameters_NEW_attachOffset :: Int -- cells to offset attach to box by
}

instance TransformMe SimpleLineSolverParameters_NEW where
  transformMe_rotateLeft = id
  transformMe_rotateRight = id
  transformMe_reflectHorizontally = id


restify :: [(CartDir, Int)] -> [(CartDir, Int, Bool)]
restify [] = []
restify ((cd,d):xs) = (cd,d,True):fmap (\(a,b) -> (a,b,False)) xs

-- used to convert AL_ANY at (ax, ay) to an AttachmentLocation based on target position (tx, ty)
-- TODO test that this function is rotationally/reflectively symmetric (although it doesn't really matter if it isn't, however due to recursive implementation of sSimpleLineSolver it's kind of awkward if it's not)
makeAL :: XY -> XY -> AttachmentLocation
makeAL (V2 ax ay) (V2 tx ty) = r where
  dx = tx - ax
  dy = ty - ay
  r = if abs dx > abs dy
    then if dx > 0
      then AL_Right
      else AL_Left
    else if dy > 0
      then AL_Bot
      else AL_Top

newtype OffsetBorder = OffsetBorder { unOffsetBorder :: Bool } deriving (Show)

instance TransformMe OffsetBorder where 
  transformMe_rotateLeft = id
  transformMe_rotateRight = id
  transformMe_reflectHorizontally = id


sSimpleLineSolver_NEW :: (Text, Int) -> SimpleLineSolverParameters_NEW -> (LBox, AttachmentLocation, OffsetBorder) -> (LBox, AttachmentLocation, OffsetBorder) -> LineAnchorsForRender
sSimpleLineSolver_NEW (errormsg, depth) sls (lbx1, al1_, offb1) (lbx2, al2_, offb2) =  finaloutput where
  --LBox (V2 x1 y1) (V2 w1 h1) = lbx1
  LBox (V2 _ y2) (V2 _ h2) = lbx2

  attachoffset = _simpleLineSolverParameters_NEW_attachOffset sls

  al1 = case al1_ of
    AL_Any -> makeAL (_lBox_tl lbx1) $ case al2_ of
      AL_Any -> _lBox_tl lbx2
      _      -> end
    x -> x
  al2 = case al2_ of
    AL_Any -> makeAL (_lBox_tl lbx2) $ case al1_ of
      AL_Any -> _lBox_tl lbx1
      _      -> start
    x -> x

  lbal1 = (lbx1, al1, offb1)
  lbal2 = (lbx2, al2, offb2)

  start@(V2 ax1 ay1) = attachLocationFromLBox (unOffsetBorder offb1) lbx1 al1
  end@(V2 ax2 ay2) = attachLocationFromLBox (unOffsetBorder offb2) lbx2 al2


  -- TODO use attach offset here
  (hsep, vsep) = determineSeparationForAttachment (lbx1, (1,1,1,1)) (lbx2, (1,1,1,1))

  lbx1isstrictlyleft = ax1 < ax2
  lbx1isleft = ax1 <= ax2
  lbx1isstrictlyabove = ay1 < ay2
  ay1isvsepfromlbx2 = ay1 < y2 || ay1 >= y2 + h2

  --traceStep = trace
  traceStep _ x = x
  stepdetail = show lbal1 <> " | " <> show lbal2 <> "\n"
  nextmsg step = (errormsg <> " " <> step <> ": " <> stepdetail, depth+1)

  (l1_inc,r1,t1_inc,b1) = lBox_to_axis lbx1
  (l2_inc,r2,t2_inc,b2) = lBox_to_axis lbx2

  -- TODO offset by boundaryoffset from parameters
  l = min (l1_inc-1) (l2_inc-1)
  t = min (t1_inc-1) (t2_inc-1)
  b = max b1 b2

  --anchors = trace (show al1 <> " " <> show al2) $ case al1 of
  anchors = case al1 of
    -- WORKING
    -- degenerate case
    AL_Right | ax1 == ax2 && ay1 == ay2 -> LineAnchorsForRender {
        _lineAnchorsForRender_start = start
        , _lineAnchorsForRender_rest = []
      }
    -- WORKING
    -- 1->  <-2
    AL_Right | al2 == AL_Left && lbx1isstrictlyleft && hsep -> traceStep "case 1" $ r where

      halfway = (ax2+ax1) `div` 2
      lb1_to_center = (CD_Right, (halfway-ax1))
      centerverticalline = if ay1 < ay2
        then (CD_Down, ay2-ay1)
        else (CD_Up, ay1-ay2)
      center_to_lb2 = (CD_Right, (ax2-halfway))
      r = LineAnchorsForRender {
          _lineAnchorsForRender_start = start
          , _lineAnchorsForRender_rest = restify [lb1_to_center, centerverticalline, center_to_lb2]
        }

    -- WORKING
    -- <-2  1->
    AL_Right | al2 == AL_Left && not vsep -> traceStep "case 2" $ r where

      goup = (ay1-t)+(ay2-t) < (b-ay1)+(b-ay2)

      -- TODO don't always need to go to max
      rightedge = (max (r1+attachoffset) r2)

      lb1_to_right = (CD_Right, rightedge-ax1)
      right_to_torb = if goup
        then (CD_Up, ay1-t)
        else (CD_Down, b-ay1)

      -- TODO sometimes need to go further
      torb = (CD_Left, rightedge - ax2 + attachoffset)

      torb_to_left = if goup
        then (CD_Down, ay2-t)
        else (CD_Up, b-ay2)
      left_to_lb2 = (CD_Right, attachoffset)
      r = LineAnchorsForRender {
          _lineAnchorsForRender_start = start
          , _lineAnchorsForRender_rest = restify [lb1_to_right, right_to_torb, torb, torb_to_left, left_to_lb2]
        }

    -- WORKING
    -- <-2
    --      1->
    AL_Right | al2 == AL_Left && vsep -> traceStep "case 3" $ r where
      halfway = (ay2+ay1) `div` 2
      lb1_to_right = (CD_Right, attachoffset)
      right_to_center = if lbx1isstrictlyabove
        then (CD_Down, halfway-ay1)
        else (CD_Up, ay1-halfway)
      center = (CD_Left, attachoffset*2 + (ax1-ax2))
      center_to_left = if lbx1isstrictlyabove
        then (CD_Down, ay2-halfway)
        else (CD_Up, halfway-ay2)
      left_to_lb2 = (CD_Right, attachoffset)
      r = LineAnchorsForRender {
          _lineAnchorsForRender_start = start
          , _lineAnchorsForRender_rest = restify [lb1_to_right, right_to_center, center, center_to_left, left_to_lb2]
        }

    -- WORKING
    -- not vsep is the wrong condition here, we want ay1 to be above or below lbx2
    -- 1->
    --     2->
    AL_Right | al2 == AL_Right && ay1isvsepfromlbx2 -> traceStep "case 4" $ answer where
      rightedge = max r1 r2 + attachoffset
      lb1_to_right1 = (CD_Right, rightedge-r1)
      right1_to_right2 = if lbx1isstrictlyabove
        then (CD_Down, ay2-ay1)
        else (CD_Up, ay1-ay2)
      right2_to_lb2 = (CD_Left, rightedge-r2)
      answer = LineAnchorsForRender {
          _lineAnchorsForRender_start = start
          , _lineAnchorsForRender_rest = restify [lb1_to_right1, right1_to_right2, right2_to_lb2]
        }

    -- WORKING
    -- ->1 ->2
    AL_Right | al2 == AL_Right && lbx1isleft && not ay1isvsepfromlbx2 -> traceStep "case 5" $  r where
      t = min (t1_inc-1) (t2_inc-1)
      b = max b1 b2
      goup = (ay1-t)+(ay2-t) < (b-ay1)+(b-ay2)

      -- TODO maybe it would be nice if this traveled a little further right
      lb1_to_right1 = (CD_Right, attachoffset)

      right1_to_torb = if goup
        then (CD_Up, ay1-t)
        else (CD_Down, b-ay1)
      torb = (CD_Right, r2-r1)
      torb_to_right2 = if goup
        then (CD_Down, ay2-t)
        else (CD_Up, b-ay2)
      right2_to_lb2 = (CD_Left, attachoffset)
      r = LineAnchorsForRender {
          _lineAnchorsForRender_start = start
          , _lineAnchorsForRender_rest = restify [lb1_to_right1, right1_to_torb, torb, torb_to_right2, right2_to_lb2]
        }
    -- ->2 ->1 (will not get covered by rotation)
    AL_Right | al2 == AL_Right && not ay1isvsepfromlbx2 -> traceStep "case 6 (reverse)" $ lineAnchorsForRender_reverse $ sSimpleLineSolver_NEW (nextmsg "case 6") sls lbal2 lbal1

    --     2->
    -- ^
    -- |
    -- 1
    --     2->
    AL_Top | al2 == AL_Right && lbx1isleft -> traceStep "case 7" $ r where
      upd = if vsep
        then attachoffset
        else ay1-t + attachoffset
      topline = ay1-upd
      lb1_to_up = (CD_Up, upd)
      right = if topline < ay2
        then (max ax2 r1) + attachoffset
        else ax2 + attachoffset
      up_to_right1 =  (CD_Right, right-ax1)
      right1_to_right2 = if topline < ay2
        then (CD_Down, ay2-topline)
        else (CD_Up, topline-ay2)
      right2_to_lb2 = (CD_Left, right-ax2)
      r = LineAnchorsForRender {
          _lineAnchorsForRender_start = start
          , _lineAnchorsForRender_rest = restify [lb1_to_up,up_to_right1,right1_to_right2,right2_to_lb2]
        }
    --     <-2
    -- ^
    -- |
    -- 1   <-2 (this one handles both vsep cases)
    AL_Top | al2 == AL_Left && lbx1isleft -> traceStep "case 9" $ r where
      topedge = min (ay1 - attachoffset) ay2
      leftedge = l
      halfway = (ax1 + ax2) `div` 2

      lb1_to_up = (CD_Up, ay1-topedge)
      (up_to_over, up_to_over_xpos) = if lbx1isstrictlyabove && not hsep
        -- go around from the left
        then ((CD_Left, ax1-leftedge), leftedge)
        else ((CD_Right, halfway-ax1), halfway)
      over_to_down = (CD_Down, ay2-topedge)
      down_to_lb2 = (CD_Right, ax2-up_to_over_xpos)
      r = LineAnchorsForRender {
          _lineAnchorsForRender_start = start
          , _lineAnchorsForRender_rest = restify [lb1_to_up, up_to_over,over_to_down,down_to_lb2]
        }

    --        ^
    --        |
    -- <-2->  1 (will not get covered by rotation)
    AL_Top | al2 == AL_Left || al2 == AL_Right -> traceStep "case 10 (flip)" $  transformMe_reflectHorizontally $ sSimpleLineSolver_NEW (nextmsg "case 10") (transformMe_reflectHorizontally sls) (transformMe_reflectHorizontally lbal1) (transformMe_reflectHorizontally lbal2)

    -- TODO DELETE these are handled earlier by substitution
    AL_Top | al2 == AL_Any -> traceStep "case 11 (any)" $ sSimpleLineSolver_NEW (nextmsg "case 11") sls lbal1 (lbx2, AL_Left, offb2)
    AL_Any | al2 == AL_Top -> traceStep "case 12 (any)" $ sSimpleLineSolver_NEW (nextmsg "case 12") sls (lbx1, AL_Right, offb1) lbal2
    AL_Any | al2 == AL_Any -> traceStep "case 13 (any)" $ sSimpleLineSolver_NEW (nextmsg "case 13") sls (lbx1, AL_Right, offb1) (lbx2, AL_Left, offb2 )

    _ -> traceStep "case 14 (rotate)" $ transformMe_rotateRight $ sSimpleLineSolver_NEW (nextmsg "case 14") (transformMe_rotateLeft sls) (transformMe_rotateLeft lbal1) (transformMe_rotateLeft lbal2)

  finaloutput = if depth > 10
    then error errormsg
    else lineAnchorsForRender_simplify anchors

doesLineContain :: XY -> XY -> (CartDir, Int, Bool) -> Maybe Int
doesLineContain (V2 px py) (V2 sx sy) (tcd, tl, _) = case tcd of
  CD_Left | py == sy -> if px <= sx && px >= sx-tl then Just (sx-px) else Nothing
  CD_Right | py == sy -> if px >= sx && px <= sx+tl then Just (px-sx) else Nothing
  CD_Up | px == sx -> if py <= sy && py >= sy-tl then Just (sy-py) else Nothing
  CD_Down | px == sx -> if py >= sy && py <= sy+tl then Just (py-sy) else Nothing
  _ -> Nothing

-- TODO test
doesLineContainBox :: LBox -> XY -> (CartDir, Int, Bool) -> Bool
doesLineContainBox lbox (V2 sx sy) (tcd, tl, _) = r where
  (x,y, w,h) = case tcd of
    CD_Left -> (sx-tl, sy, tl+1, 1)
    CD_Right -> (sx, sy, tl+1, 1)
    CD_Up -> (sx, sy-tl, 1, tl+1)
    CD_Down -> (sx, sy, 1, tl+1)
  lbox2 = LBox (V2 x y) (V2 w h)
  r = does_lBox_intersect lbox lbox2


walkToRender :: SuperStyle -> LineStyle -> LineStyle -> Bool -> XY -> (CartDir, Int, Bool) -> Maybe (CartDir, Int, Bool) -> Int -> (XY, MPChar)
walkToRender ss@SuperStyle {..} ls lse isstart begin (tcd, tl, _) mnext d = r where
  currentpos = begin + (cartDirToUnit tcd) ^* d

  endorelbow = renderAnchorType ss lse $ cartDirToAnchor tcd (fmap fst3 mnext)
  startorregular = if isstart
    then if d <= tl `div` 2
      -- if we are at the start and near the beginning then render start of line
      then renderLineEnd ss ls (flipCartDir tcd) d
      else if isNothing mnext
        -- if we are not at the start and at the end then render end of line
        then renderLineEnd ss ls tcd (tl-d)
        -- otherwise render line as usual
        else renderLine ss tcd
    else renderLine ss tcd
  r = if d == tl
    then (currentpos, endorelbow)
    else (currentpos, startorregular)

lineAnchorsForRender_renderAt :: SuperStyle -> LineStyle -> LineStyle -> LineAnchorsForRender -> XY -> MPChar
lineAnchorsForRender_renderAt ss ls lse LineAnchorsForRender {..} pos = r where
  walk (isstart, curbegin) a = case a of
    [] -> Nothing
    x:xs -> case doesLineContain pos curbegin x of
      Nothing ->  walk (False, nextbegin) xs
      Just d -> Just $ case xs of
        [] -> walkToRender ss ls lse isstart curbegin x Nothing d
        y:_ -> walkToRender ss ls lse isstart curbegin x (Just y) d
      where
        nextbegin = curbegin + cartDirWithDistanceToV2 x

  manswer = walk (True, _lineAnchorsForRender_start) _lineAnchorsForRender_rest
  r = case manswer of
    Nothing -> Nothing
    Just (pos', mpchar) -> assert (pos == pos') mpchar

-- UNTESTED
-- returns index of subsegment that intersects with pos
-- e.g.
--      0 ---(x)-- 1 ------ 2
-- returns Just 0
lineAnchorsForRender_findIntersectingSubsegment :: LineAnchorsForRender -> XY -> Maybe Int
lineAnchorsForRender_findIntersectingSubsegment  LineAnchorsForRender {..} pos = r where
  walk i curbegin a = case a of
    [] -> Nothing
    x@(_,_,s):xs -> case doesLineContain pos curbegin x of
      Nothing ->  walk new_i (curbegin + cartDirWithDistanceToV2 x) xs
      Just _ -> Just new_i
      where new_i = if s then i+1 else i
  r = walk (-1) _lineAnchorsForRender_start _lineAnchorsForRender_rest

lineAnchorsForRender_doesIntersectPoint :: LineAnchorsForRender -> XY -> Bool
lineAnchorsForRender_doesIntersectPoint LineAnchorsForRender {..} pos = r where
  walk curbegin a = case a of
    [] -> False
    x:xs -> case doesLineContain pos curbegin x of
      Nothing ->  walk (curbegin + cartDirWithDistanceToV2 x) xs

      Just _ -> True
  r = walk _lineAnchorsForRender_start _lineAnchorsForRender_rest


lineAnchorsForRender_doesIntersectBox :: LineAnchorsForRender -> LBox -> Bool
lineAnchorsForRender_doesIntersectBox LineAnchorsForRender {..} lbox = r where
  walk curbegin a = case a of
    [] -> False
    x:xs -> if doesLineContainBox lbox curbegin x
      then True
      else walk (curbegin + cartDirWithDistanceToV2 x) xs
  r = walk _lineAnchorsForRender_start _lineAnchorsForRender_rest

sSimpleLineNewRenderFn :: SAutoLine -> Maybe LineAnchorsForRender -> SEltDrawer
sSimpleLineNewRenderFn ssline@SAutoLine {..} mcache = drawer where

  getAnchors :: (HasOwlTree a) => a -> LineAnchorsForRender
  getAnchors ot = case mcache of
    Just x -> x
    Nothing -> sSimpleLineNewRenderFnComputeCache ot ssline

  renderfn :: SEltDrawerRenderFn
  renderfn ot xy = r where
    anchors = getAnchors ot
    r = lineAnchorsForRender_renderAt _sAutoLine_superStyle _sAutoLine_lineStyle _sAutoLine_lineStyleEnd anchors xy

  boxfn :: SEltDrawerBoxFn
  boxfn ot = case nonEmpty (lineAnchorsForRender_toPointList (getAnchors ot)) of
    Nothing -> LBox 0 0
    -- add_XY_to_lBox is non-inclusive with bottom/right so we expand by 1 to make it inclusive
    Just (x :| xs) -> lBox_expand (foldl' (flip add_XY_to_lBox) (make_0area_lBox_from_XY x) xs) (0,1,0,1)



  drawer = SEltDrawer {
      _sEltDrawer_box = boxfn
      , _sEltDrawer_renderFn = renderfn
    }

lineAnchorsForRender_concat :: [LineAnchorsForRender] -> LineAnchorsForRender
lineAnchorsForRender_concat [] = error "expected at least one LineAnchorsForRender"
lineAnchorsForRender_concat (x:xs) = foldl' foldfn x xs where
  -- TODO re-enable assert when it gets fixed
  foldfn h c = --assert (lineAnchorsForRender_end h == _lineAnchorsForRender_start c) $
    h { _lineAnchorsForRender_rest = _lineAnchorsForRender_rest h <> _lineAnchorsForRender_rest c }


pairs :: [a] -> [(a, a)]
pairs [] = []
pairs xs = zip xs (tail xs)

maybeGetAttachBox :: (HasOwlTree a) => a -> Maybe Attachment -> Maybe (LBox, AttachmentLocation)
maybeGetAttachBox ot mattachment = do
  Attachment rid al <- mattachment
  sowl <- hasOwlTree_findSuperOwl ot rid
  sbox <- getSEltBox_naive $ hasOwlItem_toSElt_hack sowl
  return (sbox, al)

sAutoLine_to_lineAnchorsForRenders :: (HasOwlTree a) => a -> SAutoLine -> [LineAnchorsForRender]
sAutoLine_to_lineAnchorsForRenders ot SAutoLine {..} = anchorss where

  -- TODO set properly
  params = SimpleLineSolverParameters_NEW {
      -- TODO maybe set this based on arrow head size (will differ for each end so you need 4x)
      _simpleLineSolverParameters_NEW_attachOffset = 1
    }

  offsetBorder x (a,b) = (a,b, OffsetBorder x)
  startlbal = offsetBorder True $ fromMaybe (LBox _sAutoLine_start 1, AL_Any) $ maybeGetAttachBox ot _sAutoLine_attachStart
  endlbal = offsetBorder True $ fromMaybe (LBox _sAutoLine_end 1, AL_Any) $ maybeGetAttachBox ot _sAutoLine_attachEnd
  midlbals = fmap (\(SAutoLineConstraintFixed xy) -> offsetBorder False (LBox xy 1, AL_Any)) _sAutoLine_midpoints

  -- TODO BUG this is a problem, you need selective offsetting for each side of the box, in particular, midpoints can't offset and the point needs to land exactly on the midpoint
  -- NOTE for some reason sticking trace statements in sSimpleLineSolver will causes regenanchors to get called infinite times :(
  anchorss = fmap (\(lbal1, lbal2) -> sSimpleLineSolver_NEW ("",0) params lbal1 lbal2) $ pairs ((startlbal : midlbals) <> [endlbal])


sSimpleLineNewRenderFnComputeCache :: (HasOwlTree a) => a -> SAutoLine -> LineAnchorsForRender
sSimpleLineNewRenderFnComputeCache ot sline = anchors where
  anchors = lineAnchorsForRender_concat $ sAutoLine_to_lineAnchorsForRenders ot sline 
