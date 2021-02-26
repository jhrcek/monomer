{-# LANGUAGE FlexibleContexts #-}

module Monomer.Widgets.StackSpec (spec) where

import Control.Lens ((&), (^.), (.~))
import Data.Text (Text)
import Test.Hspec

import qualified Data.Sequence as Seq

import Monomer.Core
import Monomer.Core.Combinators
import Monomer.Event
import Monomer.TestUtil
import Monomer.Widgets.Label
import Monomer.Widgets.Spacer
import Monomer.Widgets.Stack

import qualified Monomer.Lens as L

-- Event handling (ignoreEmptyClick) is tested in zstack
spec :: Spec
spec = describe "Stack" $ do
  getSizeReq
  resize

getSizeReq :: Spec
getSizeReq = describe "getSizeReq" $ do
  getSizeReqEmpty
  getSizeReqItems
  getSizeReqUpdater

getSizeReqEmpty :: Spec
getSizeReqEmpty = describe "empty" $ do
  it "should return Fixed width = 0" $
    sizeReqW `shouldBe` fixedSize 0

  it "should return Fixed height = 0" $
    sizeReqH `shouldBe` fixedSize 0

  where
    wenv = mockWenv ()
    vstackNode = vstack []
    (sizeReqW, sizeReqH) = nodeGetSizeReq wenv vstackNode

getSizeReqItems :: Spec
getSizeReqItems = describe "several items" $ do
  it "should return width = Fixed 80" $
    sizeReqW `shouldBe` fixedSize 80

  it "should return height = Fixed 60" $
    sizeReqH `shouldBe` fixedSize 60

  where
    wenv = mockWenv ()
    vstackNode = vstack [
        label "Hello",
        label "how",
        label "are you?"
      ]
    (sizeReqW, sizeReqH) = nodeGetSizeReq wenv vstackNode

getSizeReqUpdater :: Spec
getSizeReqUpdater = describe "getSizeReqUpdater" $ do
  it "should return width = Min 50 2" $
    sizeReqW `shouldBe` minSize 50 2

  it "should return height = Max 20" $
    sizeReqH `shouldBe` maxSize 20 3

  where
    wenv = mockWenv ()
    updater (rw, rh) = (minSize (rw ^. L.fixed) 2, maxSize (rh ^. L.fixed) 3)
    vstackNode = vstack_ [sizeReqUpdater updater] [label "Label"]
    (sizeReqW, sizeReqH) = nodeGetSizeReq wenv vstackNode

resize :: Spec
resize = describe "resize" $ do
  resizeEmpty
  resizeFlexibleH
  resizeFlexibleV
  resizeStrictFlexH
  resizeStrictFlexV
  resizeMixedH
  resizeMixedV
  resizeAllV
  resizeNoSpaceV
  resizeSpacerFlexH
  resizeSpacerFixedH

resizeEmpty :: Spec
resizeEmpty = describe "empty" $ do
  it "should have the provided viewport size" $
    viewport `shouldBe` vp

  it "should not have children" $
    children `shouldSatisfy` Seq.null

  where
    wenv = mockWenv ()
    -- Main axis is adjusted to content
    vp = Rect 0 0 640 0
    vstackNode = vstack []
    newNode = nodeInit wenv vstackNode
    viewport = newNode ^. L.info . L.viewport
    children = newNode ^. L.children

resizeFlexibleH :: Spec
resizeFlexibleH = describe "flexible items, horizontal" $ do
  it "should have the provided viewport size" $
    viewport `shouldBe` vp

  it "should assign size proportional to requested size to each children" $
    childrenVp `shouldBe` Seq.fromList [cvp1, cvp2, cvp3]

  where
    wenv = mockWenv () & L.windowSize .~ Size 480 640
    vp   = Rect   0 0 480 640
    cvp1 = Rect   0 0 112 640
    cvp2 = Rect 112 0 256 640
    cvp3 = Rect 368 0 112 640
    hstackNode = hstack [
        label_ "Label 1" [resizeFactorW 0.01],
        label_ "Label Number Two" [resizeFactorW 0.01],
        label_ "Label 3" [resizeFactorW 0.01]
      ]
    newNode = nodeInit wenv hstackNode
    viewport = newNode ^. L.info . L.viewport
    childrenVp = roundRectUnits . _wniViewport . _wnInfo <$> newNode ^. L.children

resizeFlexibleV :: Spec
resizeFlexibleV = describe "flexible items, vertical" $ do
  it "should have the provided viewport size" $
    viewport `shouldBe` vp

  it "should assign size proportional to requested size to each children" $
    childrenVp `shouldBe` Seq.fromList [cvp1, cvp2, cvp3]

  where
    wenv = mockWenv ()
    vp   = Rect 0   0 640 480
    cvp1 = Rect 0   0 640 160
    cvp2 = Rect 0 160 640 160
    cvp3 = Rect 0 320 640 160
    vstackNode = vstack [
        label "Label 1" `style` [flexHeight 20],
        label "Label Number Two" `style` [flexHeight 20],
        label "Label 3" `style` [flexHeight 20]
      ]
    newNode = nodeInit wenv vstackNode
    viewport = newNode ^. L.info . L.viewport
    childrenVp = (^. L.info . L.viewport) <$> newNode ^. L.children

resizeStrictFlexH :: Spec
resizeStrictFlexH = describe "strict/flexible items, horizontal" $ do
  it "should have the provided viewport size" $
    viewport `shouldBe` vp

  it "should assign requested size to the main labels and the rest to grid" $
    childrenVp `shouldBe` Seq.fromList [cvp1, cvp2, cvp3]

  where
    wenv = mockWenv ()
    vp   = Rect   0 0 640 480
    cvp1 = Rect   0 0 100 480
    cvp2 = Rect 100 0 100 480
    cvp3 = Rect 200 0 440 480
    hstackNode = hstack [
        label_ "Label 1" [resizeFactorW 0.01] `style` [width 100],
        label_ "Label 2" [resizeFactorW 0.01] `style` [width 100],
        label_ "Label 3" [resizeFactorW 0.01]
      ]
    newNode = nodeInit wenv hstackNode
    viewport = newNode ^. L.info . L.viewport
    childrenVp = (^. L.info . L.viewport) <$> newNode ^. L.children

resizeStrictFlexV :: Spec
resizeStrictFlexV = describe "strict/flexible items, vertical" $ do
  it "should have the provided viewport size" $
    viewport `shouldBe` vp

  it "should assign requested size to the main labels and the rest to grid" $
    childrenVp `shouldBe` Seq.fromList [cvp1, cvp2, cvp3]

  where
    wenv = mockWenv ()
    vp   = Rect 0   0 640 480
    cvp1 = Rect 0   0 640 100
    cvp2 = Rect 0 100 640  20
    cvp3 = Rect 0 120 640 360
    vstackNode = vstack [
        label "Label 1" `style` [height 100],
        label "Label 2",
        label "Label 3" `style` [flexHeight 100]
      ]
    newNode = nodeInit wenv vstackNode
    viewport = newNode ^. L.info . L.viewport
    childrenVp = (^. L.info . L.viewport) <$> newNode ^. L.children

resizeMixedH :: Spec
resizeMixedH = describe "mixed items, horizontal" $ do
  it "should have the provided viewport size" $
    viewport `shouldBe` vp

  it "should assign size proportional to requested size to each children" $
    childrenVp `shouldBe` Seq.fromList [cvp1, cvp2]

  where
    wenv = mockWenv ()
    vp   = Rect   0 0 640  20
    cvp1 = Rect   0 0 196  20
    cvp2 = Rect 196 0 444  20
    hstackNode = vstack [
        hstack [
          label_ "Short label" [resizeFactorW 0.01],
          label_ "This label is much longer" [resizeFactorW 0.01]
        ]
      ]
    newNode = nodeInit wenv hstackNode
    viewport = newNode ^. L.info . L.viewport
    firstChild = Seq.index (newNode ^. L.children) 0
    childrenVp = roundRectUnits . _wniViewport . _wnInfo <$> firstChild ^. L.children

resizeMixedV :: Spec
resizeMixedV = describe "mixed items, vertical" $ do
  it "should have the provided viewport size" $
    viewport `shouldBe` vp

  it "should assign size proportional to requested size to each children" $
    childrenVp `shouldBe` Seq.fromList [cvp1, cvp2, cvp3]

  where
    wenv = mockWenv ()
    vp   = Rect 0   0 640 480
    cvp1 = Rect 0   0 640  20
    cvp2 = Rect 0  20 640 426
    cvp3 = Rect 0 446 640  34
    vstackNode = hstack [
        vstack [
          label_ "Label 1" [resizeFactorW 0.01],
          label_ "Label 2" [resizeFactorW 0.01] `style` [minHeight 250],
          label_ "Label 3" [resizeFactorW 0.01] `style` [flexHeight 20]
        ]
      ]
    newNode = nodeInit wenv vstackNode
    viewport = newNode ^. L.info . L.viewport
    firstChild = Seq.index (newNode ^. L.children) 0
    childrenVp = roundRectUnits . _wniViewport . _wnInfo <$> firstChild ^. L.children

resizeAllV :: Spec
resizeAllV = describe "all kinds of sizeReq, vertical" $ do
  it "should have the provided viewport size" $
    viewport `shouldBe` vp

  it "should assign size proportional to requested size to each children" $
    childrenVp `shouldBe` Seq.fromList [cvp1, cvp2, cvp3, cvp4, cvp5]

  where
    wenv = mockWenv ()
    vp   = Rect 0   0 640 480
    cvp1 = Rect 0   0 640  50
    cvp2 = Rect 0  50 640 115
    cvp3 = Rect 0 165 640 135
    cvp4 = Rect 0 300 640  80
    cvp5 = Rect 0 380 640 100
    vstackNode = vstack [
        label "Label 1" `style` [width 50, height 50],
        label "Label 2" `style` [flexWidth 60, flexHeight 60],
        label "Label 3" `style` [minWidth 70, minHeight 70],
        label "Label 4" `style` [maxWidth 80, maxHeight 80],
        label "Label 5" `style` [rangeWidth 90 100, rangeHeight 90 100]
      ]
    newNode = nodeInit wenv vstackNode
    viewport = newNode ^. L.info . L.viewport
    childrenVp = roundRectUnits . _wniViewport . _wnInfo <$> newNode ^. L.children

resizeNoSpaceV :: Spec
resizeNoSpaceV = describe "vertical, without enough space" $ do
  it "should have a larger viewport size (parent should fix it)" $ do
    viewport `shouldBe` vp
    viewport `shouldBe` vp

  it "should assign size proportional to requested size to each children" $
    childrenVp `shouldBe` Seq.fromList [cvp1, cvp2, cvp3, cvp4, cvp5]

  where
    wenv = mockWenv ()
    vp   = Rect 0   0 640 800
    cvp1 = Rect 0   0 640 200
    cvp2 = Rect 0 200 640 200
    cvp3 = Rect 0 400 640   0
    cvp4 = Rect 0 400 640 200
    cvp5 = Rect 0 600 640 200
    vstackNode = vstack [
        label "Label 1" `style` [height 200],
        label "Label 2" `style` [height 200],
        label "Label 3" `style` [flexHeight 200],
        label "Label 4" `style` [height 200],
        label "Label 5" `style` [height 200]
      ]
    newNode = nodeInit wenv vstackNode
    viewport = newNode ^. L.info . L.viewport
    childrenVp = roundRectUnits . _wniViewport . _wnInfo <$> newNode ^. L.children

resizeSpacerFlexH :: Spec
resizeSpacerFlexH = describe "label flex and spacer, horizontal" $ do
  it "should have the provided viewport size" $
    roundRectUnits viewport `shouldBe` vp

  it "should assign size proportional to requested size to each children" $
    childrenVp `shouldBe` Seq.fromList [cvp1, cvp2, cvp3]

  where
    wenv = mockWenv ()
    vp   = Rect   0 0 640 480
    cvp1 = Rect   0 0 211 480
    cvp2 = Rect 211 0   8 480
    cvp3 = Rect 219 0 421 480
    hstackNode = hstack [
        label "Label" `style` [flexWidth 100],
        hfiller,
        label "Label" `style` [flexWidth 200]
      ]
    newNode = nodeInit wenv hstackNode
    viewport = newNode ^. L.info . L.viewport
    childrenVp = roundRectUnits . _wniViewport . _wnInfo <$> newNode ^. L.children

resizeSpacerFixedH :: Spec
resizeSpacerFixedH = describe "label fixed and spacer, horizontal" $ do
  it "should have the provided viewport size" $
    viewport `shouldBe` vp

  it "should assign size proportional to requested size to each children" $
    childrenVp `shouldBe` Seq.fromList [cvp1, cvp2, cvp3]

  where
    wenv = mockWenv ()
    vp   = Rect   0 0 640 480
    cvp1 = Rect   0 0 100 480
    cvp2 = Rect 100 0 340 480
    cvp3 = Rect 440 0 200 480
    hstackNode = hstack [
        label "Label" `style` [width 100],
        hfiller,
        label "Label" `style` [width 200]
      ]
    newNode = nodeInit wenv hstackNode
    viewport = newNode ^. L.info . L.viewport
    childrenVp = roundRectUnits . _wniViewport . _wnInfo <$> newNode ^. L.children
