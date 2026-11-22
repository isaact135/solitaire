# App Store listing

Everything to enter in App Store Connect for version 1.0. Images are in `screenshots/` and `creative/`. All of them are opaque PNGs, because App Store Connect rejects images with transparency.

## App Information

- **Name:** whichever name App Store Connect accepted (Ace of Hearts Solitaire, Quiet Solitaire or Tidy Solitaire).
- **Subtitle:** `Classic Klondike card game`
- **Category:** Games, with the subcategories Card and Casual.
- **Content rights:** No, the app doesn't contain, show or access third-party content.
- **Age rating:** answer None or No to every question. It should come out as 4+.

## App Privacy

- **Privacy Policy URL:** `https://isaact135.github.io/solitaire/privacy/`
- **Data collection:** choose "No, we do not collect data from this app". The listing then shows "Data Not Collected".

## App Compliance

These declarations are for the China mainland storefront.

- **AI-Generated or Synthetic Content:** No. The app has no AI features: no chatbot, no image, video or voice generation, and no face editing.
- **Security Assessment:** No. It's required only for apps that distribute AI-generated content or offer end-to-end encrypted messaging.

## Pricing and Availability

- **Price:** your choice. A free app needs no extra agreements; a paid one needs the Paid Apps agreement and your tax and banking details.
- **Availability:** all countries, unless you leave out the EU to avoid the trader declaration.
- **Mac and Apple Vision Pro:** turn both off, so the app stays iPhone only.

## Version 1.0

**Screenshots:** upload each folder to its slot, keeping the files in numbered order.

| Slot | Folder | Size |
| --- | --- | --- |
| iPhone with Dynamic Island (medium display), required | `screenshots/iphone-medium/` | 1206 × 2622 |
| iPhone with Dynamic Island (large display) | `screenshots/iphone-large/` | 1320 × 2868 |
| iPhone Duo (outer display) | `screenshots/duo-outer/` | 1398 × 2034 |
| iPhone Duo (inner display) | `screenshots/duo-inner/` | 2853 × 2007, landscape, half open |

- **Medium slot:** it's required, and it only accepts 1206 × 2622 or 1179 × 2556. Upload `iphone-medium` there; a larger size gets the "file dimensions are invalid" error.
- **Large slot:** optional. It gives the biggest iPhones screenshots made at their own size.

**App preview:** `previews/iphone-preview.mp4`, optional.
- **What it shows:** 22.6 seconds, recorded in the app. A card goes home, a card flips, a run is dragged across, the stock is drawn, then eight taps send the last cards home and the win screen appears.
- **Format:** 886 × 1920, 30 fps, H.264 with silent stereo AAC audio, as Apple specifies for iPhone previews.
- **Where it goes:** the same file fits both iPhone with Dynamic Island slots, medium and large.
- **Poster frame:** set it to about 8 seconds, where the dragged run makes a long column. The default is 5 seconds.
- **iPhone Duo:** the Duo slots are optional until April 2027. From then they're required for apps built with the iOS 27.1 SDK or later, which includes this one. Uploading them now adds an iPhone Duo badge to the product page.

**Promotional text** (165 of 170 characters; you can change it at any time without a new version):

```
Classic Klondike with Draw 1 or Draw 3, standard scoring with a time bonus, and a heads-up when you run out of useful moves. No ads, no tracking, no internet needed.
```

**Description** (1,114 of 4,000 characters):

```
Classic Klondike solitaire, made for iPhone. Build each suit from ace to king on a green felt table, at your own pace.

PLAY YOUR WAY
• Draw 1 for a relaxed game, or Draw 3 for traditional Klondike rules
• Drag cards and stacks, or tap a card to send it where it fits
• Take back moves with Undo
• Your game saves automatically and picks up where you left off

KNOWS WHEN YOU'RE STUCK
When no move can turn over another card or play one from the deck, the game lets you know, even when the only moves left go in circles. Undo, deal again or keep looking.

STANDARD SCORING
Earn points for building the foundations and turning over cards, lose some for taking cards back or going through the deck again, and earn a time bonus when you win. The faster you finish, the bigger the bonus.

MADE FOR iPHONE
• Portrait and landscape layouts that fit your screen
• On iPhone Duo, the board splits around the fold when the phone is half open
• Gentle haptics, VoiceOver and Reduce Motion support

NO ADS. NO TRACKING.
No accounts, no ads and no internet connection needed. The app doesn't collect any information about you.
```

**Keywords** (93 of 100 characters). Words already in the name and subtitle count on their own, so they aren't repeated here:

```
patience,offline,no ads,relaxing,casual,puzzle,brain,logic,deck,tableau,solo,draw,timer,score
```

- **Support URL:** `https://isaact135.github.io/solitaire/support/`
- **Marketing URL:** leave blank.
- **Copyright:** `2026 Isaac Torres`

## Header and Search Results

These are optional artwork that iOS 27 and later shows on the product page and in search results. Upload them under Product Page Information, in the Header and Search Results tab. They don't need a new app version.

- **Header:** `creative/header.png` (3840 × 1646), the icon's four aces on felt. The aces sit inside Apple's art safe area, so narrower screens crop only felt and the decks at the sides.
- **Search results:** `creative/search-results.png` (1920 × 1280), a real game on the unfolded iPhone Duo. Apple recommends showing actual gameplay here.

## App Review Information

- **Sign-in required:** No.
- **Contact information:** your name, phone number and email. Only Apple sees these.
- **Notes:**

```
No sign-in is needed. The app works entirely offline and collects no data.
```

## Version Release

Choose **Manually release this version**, so you pick the moment it goes live after approval.
