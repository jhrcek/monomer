module Monomer.Widgets.ImageSpec (spec) where

import Data.Text (Text)
import Test.Hspec

import qualified Data.Sequence as Seq

import Monomer.Core
import Monomer.Event
import Monomer.TestUtil
import Monomer.Widgets.Image

spec :: Spec
spec = describe "Image"
  initMergeWidget

initMergeWidget :: Spec
initMergeWidget = describe "init/merge" $ do
  it "should create a RunTask on init" $ do
    Seq.length reqs1 `shouldBe` 1
    Seq.index reqs1 0 `shouldSatisfy` isRunTask

  it "should not create a task when merging to the same path" $
    Seq.length reqs2 `shouldBe` 0

  it "should create a task when merging to a different path" $ do
    Seq.length reqs3 `shouldBe` 1
    Seq.index reqs3 0 `shouldSatisfy` isRunTask

  where
    wenv = mockWenv ()
    inst1 = image "assets/images/beach.jpg"
    inst2 = image "assets/images/beach.jpg"
    inst3 = image "assets/images/beach2.jpg"
    WidgetResult reqs1 _ newInst1 = widgetInit (_wiWidget inst1) wenv inst1
    WidgetResult reqs2 _ _ = widgetMerge (_wiWidget inst2) wenv () newInst1 inst2
    WidgetResult reqs3 _ _ = widgetMerge (_wiWidget inst3) wenv () newInst1 inst3

isRunTask :: WidgetRequest s -> Bool
isRunTask RunTask{} = True
isRunTask _ = False