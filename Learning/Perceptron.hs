{-# LANGUAGE ConstraintKinds, FlexibleContexts #-}

-- | A perceptron is a supervised learning algorithm for binary linear
-- classification.
--
-- A binay classificator maps a feature vector to a boolean value. A binary
-- linear classifier uses a linear combination of the vector's components to
-- classify the vector. The perceptron can be used as an online or offline
-- learning algorithm.
--
-- The credit for a perceptron is given to Frank Rosenbltt at Cornell 
-- Aeronautical Laboratory in 1957.
module Learning.Perceptron (pla, applyHypothesis) where
  import Data.Tuple (swap)
  import Foreign.Storable (Storable)

  import Data.Packed.Vector (Vector(..), fromList)
  import Numeric.Container ((<.>), scale, Product, Container)
  import Numeric.LinearAlgebra ()

  import Test.QuickCheck

  -- | A `Scalar` is a primitive quantity that stores a single quantity. It
  -- can be used as the component of a vector.
  type Scalar a = (Storable a, Num a, Num (Vector a), Product a, Ord a, Container Vector a)

  -- | Applies a vector of weights to an augmented feature vector.
  applyHypothesis :: Scalar a => Vector a -> Vector a -> Bool
  applyHypothesis w = (>=0) . (w <.>)

  -- | Augments a feature vector with a bias term.
  augment :: Scalar a => [a] -> [a]
  augment = (1:)

  -- | The defacto iterative learning algorithm for training a perceptron. If 
  -- the data is linearly seperable, then the algorithm will produce a 
  -- function that will classify all the inputs correctly and hopefully new 
  -- inputs as well. If data is not linearly seperable, then the algorithm 
  -- will never terminate.
  --
  -- The algorithm repeated finds the first misclassified example and adjusts
  -- the hypothesis to classify it correctly. This is repeated  until all 
  -- (x, y) pairs are classified correctly.
  pla :: Scalar a => [([a], Bool)] -> [a] -> Bool
  pla xys 
    | null xys = const True
    | (null . fst . head) xys  = const $ snd $ head xys
    | otherwise = applyHypothesis g . fromList . augment
    where -- g is the final hypothesis that correctly classifies all the pairs.
      g = snd $ head $ dropWhile (not.null.fst) $ iterate update (missed weights0, weights0)
      datalist = map (swap . (fmap $ fromList . augment) . swap) xys
      adjustHyp hypothesis (x, y) = hypothesis + (sigbool y) `scale` x
      sigbool True  = 1
      sigbool False = -1
      weights0 = 0 * (fst $ head $ datalist)
      misclassified w (x,y) = (y /=) $ applyHypothesis w x
      missed weights = [ d | d <- datalist, (misclassified weights) d ]
      update (misses, weights) = (missed weights', weights')
        where
          weights' = adjustHyp weights $ head misses


  data PerceptronTest = PerceptronTest [([Double],Bool)] deriving Show
  instance Arbitrary PerceptronTest where
    arbitrary = do
      n <- choose (1,10) -- Pick the dimensionality
      m <- choose (1,100) -- Pick the number of training vectors
      f <- vector n :: Gen [Double] -- Pick the function that represents the world
      xs <-  mapM vector $ take m $ repeat n :: Gen [[Double]] -- Pick some vectors from the world.
      let xs' = map (\x -> (x, applyHypothesis (fromList (1:f)) (fromList (1:x)))) xs
      return $ PerceptronTest xs'

  prop_plaStable (PerceptronTest xys) = and $ map (\(x,y) -> y == p x) xys
    where
      p = pla xys
      