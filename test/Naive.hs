module Naive where

import Net.IPv4 (IPv4(..))
import Data.Text (Text)
import qualified Net.IPv4 as IPv4
import qualified Data.Text as Text
import Text.Read (readMaybe)
import Net.IPv4 (IPv4(..))
import Data.Bits ((.&.),(.|.),shiftR,shiftL,complement)
import Data.Monoid ((<>))
import Data.Text.Lazy.Builder.Int (decimal)
import Data.Text.Internal (Text(..))
import Data.Word
import Data.ByteString (ByteString)
import Control.Monad.ST
import Data.Text.Encoding (encodeUtf8)
import qualified Data.ByteString.Char8  as BC8
import qualified Data.ByteString        as ByteString
import qualified Data.ByteString.Unsafe as ByteString
import qualified Data.Text.Lazy         as LText
import qualified Data.Text.Lazy.Builder as TBuilder
import qualified Data.Text.Array        as TArray

ipv4ToByteStringChar8Naive :: IPv4 -> ByteString
ipv4ToByteStringChar8Naive =
  encodeUtf8 . ipv4ToTextNaive

ipv4ToTextNaive :: IPv4 -> Text
ipv4ToTextNaive i = Text.pack $ concat
  [ show a
  , "."
  , show b
  , "."
  , show c
  , "."
  , show d
  ]
  where (a,b,c,d) = IPv4.toOctets i

ipv4FromTextNaive :: Text -> Maybe IPv4
ipv4FromTextNaive t = 
  case mapM (readMaybe . Text.unpack) (Text.splitOn (Text.pack ".") t) of
    Just [a,b,c,d] -> Just (IPv4.fromOctets a b c d)
    _ -> Nothing

------------------------
-- Below this is a place where you can experiment
-- with alternative approaches to building or parsing
-- the different types.
------------------------

------------------------
-- This implementation operates directly on
-- a mutable array. It is the fastest one so far.
-- On a 2012 laptop, it can serialize an IPv4
-- address to Text in 35ns.
------------------------
toTextPreAllocated :: IPv4 -> Text
toTextPreAllocated (IPv4 w) =
  let w1 = fromIntegral $ 255 .&. shiftR w 24
      w2 = fromIntegral $ 255 .&. shiftR w 16
      w3 = fromIntegral $ 255 .&. shiftR w 8
      w4 = fromIntegral $ 255 .&. w
      dot = 46
      (arr,len) = runST $ do
        marr <- TArray.new 15
        i1 <- putAndCount 0 w1 marr
        let n1 = i1
            n1' = i1 + 1
        TArray.unsafeWrite marr n1 dot
        i2 <- putAndCount n1' w2 marr
        let n2 = i2 + n1'
            n2' = n2 + 1
        TArray.unsafeWrite marr n2 dot
        i3 <- putAndCount n2' w3 marr
        let n3 = i3 + n2'
            n3' = n3 + 1
        TArray.unsafeWrite marr n3 dot
        i4 <- putAndCount n3' w4 marr
        theArr <- TArray.unsafeFreeze marr
        return (theArr,i4 + n3')
  in Text arr 0 len
    
putAndCount :: Int -> Word8 -> TArray.MArray s -> ST s Int
putAndCount pos w marr
  | w < 10 = TArray.unsafeWrite marr pos (i2w w) >> return 1
  | w < 100 = write2 pos w >> return 2
  | otherwise = write3 pos w >> return 3
  where
  write2 off i0 = do
    let i = fromIntegral i0; j = i + i
    TArray.unsafeWrite marr off $ get2 j
    TArray.unsafeWrite marr (off + 1) $ get2 (j + 1)
  write3 off i0 = do
    let i = fromIntegral i0; j = i + i + i
    TArray.unsafeWrite marr off $ get3 j
    TArray.unsafeWrite marr (off + 1) $ get3 (j + 1)
    TArray.unsafeWrite marr (off + 2) $ get3 (j + 2)
  get2 = fromIntegral . ByteString.unsafeIndex twoDigits
  get3 = fromIntegral . ByteString.unsafeIndex threeDigits

zero,dot :: Word16
zero = 48
{-# INLINE zero #-}
dot = 46
{-# INLINE dot #-}

i2w :: (Integral a) => a -> Word16
i2w v = zero + fromIntegral v
{-# INLINE i2w #-}

twoDigits :: ByteString
twoDigits = BC8.pack
  "0001020304050607080910111213141516171819\
  \2021222324252627282930313233343536373839\
  \4041424344454647484950515253545556575859\
  \6061626364656667686970717273747576777879\
  \8081828384858687888990919293949596979899"

threeDigits :: ByteString
threeDigits = 
  ByteString.replicate 300 0 <> BC8.pack
  "100101102103104105106107108109110111112\
  \113114115116117118119120121122123124125\
  \126127128129130131132133134135136137138\
  \139140141142143144145146147148149150151\
  \152153154155156157158159160161162163164\
  \165166167168169170171172173174175176177\
  \178179180181182183184185186187188189190\
  \191192193194195196197198199200201202203\
  \204205206207208209210211212213214215216\
  \217218219220221222223224225226227228229\
  \230231232233234235236237238239240241242\
  \243244245246247248249250251252253254255"

-----------------------------------------
-- Text Builder implementation. This ends
-- up performing worse than the naive
-- implementation.
-----------------------------------------
toDotDecimalText :: IPv4 -> Text
toDotDecimalText = LText.toStrict . TBuilder.toLazyText . toDotDecimalBuilder
{-# INLINE toDotDecimalText #-}

toDotDecimalBuilder :: IPv4 -> TBuilder.Builder
toDotDecimalBuilder (IPv4 w) = 
  decimal (255 .&. shiftR w 24 )
  <> dot
  <> decimal (255 .&. shiftR w 16 )
  <> dot
  <> decimal (255 .&. shiftR w 8 )
  <> dot
  <> decimal (255 .&. w)
  where dot = TBuilder.singleton '.'
{-# INLINE toDotDecimalBuilder #-}

