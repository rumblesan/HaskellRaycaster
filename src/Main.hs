-- Copyright 2016 Boris Kachscovsky
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
module Main where

import Vector
import Codec.Picture
import Codec.Picture.Png
import Data.Maybe
import Data.List
import Debug.Trace
import Data.Function
import Color

-- Basic Data Types
data Object = Object Shape Material
data Material = Material Color
data Shape = Sphere Vector Double
--           | Plane Vector Vector 
--           | Triangle Vector Vector Vector
            deriving (Show, Eq)
data Light = PointLight Vector
data Camera = Camera Double Vector Vector
data Scene = Scene [Object] [Light] Camera Config
data Config = Config { sceneWidth :: Int,
                       sceneHeight :: Int,
                       defaultColor :: Color
}
data Ray = Ray {origin :: Vector, direction :: Vector}

main :: IO()
main =
  let
    objects :: [Object]
    objects = [Object
                    (Sphere (Vector (-3) 3.5 (-8)) 3)
                    (Material Color.red),
               Object
                    (Sphere (Vector 1.5 3.5 (-6)) 3)
                    (Material Color.green)]

    lights :: [Light]
    lights = [PointLight (Vector (-30) (-10) 20) ]

    camera :: Camera
    camera = Camera 45 (Vector 0 1.8 10) (Vector 0 3 0)

    config = Config 500 500 Color.white

    scene :: Scene
    scene = Scene objects lights camera config

    img = generateImage (\x y -> Color.color2Px $ Main.trace scene x y) (sceneWidth config) (sceneHeight config)
   in
    writePng "output.png" img

trace :: Scene -> Int -> Int -> Color
trace (Scene objects lights camera config) x y =
    let
      ray =  generateRay camera (sceneWidth config) (sceneHeight config) x y
      intersections = closestIntersection ray objects
    in
      case intersections of Nothing -> defaultColor config
                            Just distObj -> getColorFromIntersection distObj

getColorFromIntersection :: (Double, Object) -> Color
getColorFromIntersection ( _ , Object _ (Material color)) = color

-- Generating rays, assuming distance to the image is 1 unit
generateRay :: Camera -> Int -> Int -> Int -> Int -> Ray
generateRay camera width height x y = 
    let 
         -- Vector from camera to lookAt point
        eyeVector = buildEyeVector camera 
        -- Vector in local right direction
        rightVector = normalize (eyeVector `cross` Vector 0 1 0)
        upVector = normalize (rightVector `cross` eyeVector)
        -- Halves are taken to make right angles
        halfFov = fovInRadians camera
        -- This aspect ratio will be used, but are not the width and height of the camera
        aspectRatio = h / w
        halfWidth = tan halfFov
        halfHeight = aspectRatio * halfWidth
        cameraWidth = halfWidth * 2
        cameraHeight = halfHeight * 2
        pixelWidth = cameraWidth / (w - 1)
        pixelHeight = cameraHeight / (h - 1)
        scaledX = ((fromIntegral x * pixelWidth) - halfWidth)  `scalarMult` rightVector
        scaledY = ((fromIntegral y * pixelHeight) - halfHeight) `scalarMult`  upVector 
        orientation = normalize $ eyeVector `add` scaledX `add` scaledY
    in  Ray (getPosition camera) orientation
    where w = fromIntegral width
          h = fromIntegral height

buildEyeVector :: Camera -> Vector
buildEyeVector (Camera _ location lookAt) = normalize (lookAt `sub` location)

fovInRadians :: Camera -> Double
fovInRadians (Camera fov _ _ ) = pi * (fov / 2) / 180

getPosition :: Camera -> Vector
getPosition (Camera _ position _ ) = position

closestIntersection :: Ray -> [Object] -> Maybe (Double, Object)
closestIntersection ray objects
    | null intersections = Nothing
    | otherwise = Just $ minimumBy minimumDefinedByFirst intersections
    where intersections = catMaybes $ map (intersects ray) objects

minimumDefinedByFirst :: (Double, Object) -> (Double,Object) -> Ordering
minimumDefinedByFirst  x y
    | fst x < fst y = LT
    | fst x > fst y = GT
    | otherwise = EQ

-- Minimum distance intersection
intersects :: Ray -> Object -> Maybe (Double, Object)
intersects (Ray origin direction) object@(Object (Sphere center radius) material) =
    let
        l = origin `sub` center
        a = direction `dot` direction
        b = 2 * (direction `dot` l)
        c =  (l `dot` l) - radius^2
        listOfRoots = roots a b c
    in
        case listOfRoots of
            [] -> Nothing
            otherwise -> Just (minimum listOfRoots, object)

-- Finds a,b, and c for a^2*x + b*x + c*x = 0, useful for finding intersections
roots :: Double -> Double -> Double -> [Double]
roots a b c
    | descriminant == 0 = [0.5 * (-b)]
    | descriminant > 0 = [0.5 * (-b + sqrt descriminant), 0.5 * (-b - sqrt descriminant)]
    | otherwise = []
    where descriminant = b * b - 4 * a * c