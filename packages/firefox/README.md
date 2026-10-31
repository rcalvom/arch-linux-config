# Firefox CSS Customization

This package maintains Firefox's blue accents and square controls as versioned
CSS and profile preferences. It is not a Firefox theme extension: standard themes
do not cover all the browser controls and internal content customized here.

## Files and scope

| File | Purpose |
| --- | --- |
| `profile-template/chrome/internal-palette.css` | Shared blue accent and navy neutral tokens for `about:` and `chrome://` UI documents. |
| `profile-template/chrome/userChrome.css` | Styles browser toolbars and tabs; hides window controls and selected toolbar shortcuts. |
| `profile-template/chrome/userContent.css` | Styles session restoration, private browsing, history sidebars and the built-in PDF viewer. |
| `profile-template/user.js` | Enables custom stylesheets and supplies the managed browser preferences. |
| `archcfg-firefox` | Copies the template into the selected profile before starting Firefox. |
| `files.conf` | Maps the launcher and template to their installed locations. |

`userChrome.css` does not style documents inside tabs. Session restoration and
PDF.js therefore need `userContent.css`. Its selectors identify the documents by
their internal stylesheet links:

- Session restoration: `chrome://browser/skin/aboutSessionRestore.css`.
- PDF.js: `resource://pdf.js/web/viewer.css`.
- Private browsing: `chrome://browser/skin/privatebrowsing/aboutPrivateBrowsing.css`,
  plus document-scoped rules for `about:privatebrowsing`.

History sidebar document rules cover both the legacy Places sidebar and the new
HTML sidebar. Shared chrome radius tokens also square history search controls and
cards. Private browsing uses a dark navy canvas and blue search/info surfaces;
the search component's own radius token is overridden, and Nova's purple backdrop
is removed. Nova's unpadded information footer retains a transparent background
so it blends into the page rather than appearing as a cramped blue card.
The private-browsing identity and explanatory text remain visible.

PDF.js retains the opened PDF's URL, so matching only a `resource://pdf.js/`
document URL would miss ordinary PDF tabs. These selectors target Firefox's
internal UI rather than ordinary websites. Content color overrides preserve
forced-colors mode.

## Palette and geometry

Both entry-point stylesheets import `internal-palette.css`. It remaps Firefox's
violet design tokens to blue and slate shades for internal UI documents, including
preferences, add-ons, dialogs and sidebars. Forced-colors mode is excluded.
Private-mode mask artwork uses a hue filter because its colors are embedded in
image assets. Hard-coded colors in other illustrations may still need targeted
rules; this is not a guarantee that every internal asset is recolored.

| Use | Color |
| --- | --- |
| Primary button | `#033e8c` |
| Primary button hover | `#0a4fa8` |
| Primary button active | `#062f6b` |
| Selected tab / dark content hover | `#082552` |
| Focus outline | `#3b82f6` |
| Dark content links and accents | `#60a5fa` |
| Dark content link hover | `#93c5fd` |
| Primary content button text | `#ffffff` |

The shared close-window confirmation dialog uses blue accent, checkbox and button
state colors. Primary confirmation buttons retain white text on blue backgrounds.

Managed control radii are zero. The styles override both Firefox design tokens
and selected controls with literal radii. The CSS files are the authoritative
source for the complete set of selectors and state colors.

Tab sizing follows the address-bar row's height: `userChrome.css` derives the
extra vertical space from `--urlbar-height`, `--urlbar-container-padding-block`
and `--tab-min-height`. With the current normal-density Nova defaults, the 32px
base height plus 8px of spacing makes a 40px row. Horizontal tab backgrounds have
zero block margins and a minimum height of `--tabstrip-min-height`, so the
selected and hovered backgrounds fill that space instead of leaving dark strips
above and below the tabs. This gives the appearance of internal padding while
keeping the controls square. Recheck alignment after changing Firefox's density
or updating its internal sizing tokens.

## Deployment and activation

The repository's package-manifest deployment installs:

- `archcfg-firefox` as `~/.local/bin/archcfg-firefox`.
- `profile-template/` as `~/.local/share/archcfg/firefox-template/`.

Launch Firefox through `archcfg-firefox` to apply the installed template. The
launcher reads the first installation-default profile from
`${XDG_CONFIG_HOME:-$HOME/.config}/mozilla/firefox/profiles.ini`. If none is found,
it uses a managed `archcfg.default-release` profile.

Before launch, it copies `user.js`, `chrome/userChrome.css`, and
`chrome/userContent.css`, and `chrome/internal-palette.css` into that profile. These managed files are overwritten
on each launcher invocation: keep intended customizations in the repository
template and deploy them to the installed template too. Back up any independent
profile edits before applying the launcher.

The preference `toolkit.legacyUserProfileCustomizations.stylesheets` must be
`true`; the template sets it in `user.js`. Fully exit Firefox and reopen it after
stylesheet changes. Reloading a tab is insufficient.

## Temporarily disabling the styles

1. Fully exit Firefox.
2. Back up the active profile's `user.js` and remove its
   `toolkit.legacyUserProfileCustomizations.stylesheets` entry temporarily.
3. Start `/usr/bin/firefox` directly with the same profile, bypassing
   `archcfg-firefox` so it does not restore the managed preference.
4. Set `toolkit.legacyUserProfileCustomizations.stylesheets` to `false` in
   `about:config`, then fully exit and reopen Firefox directly.

This disables both custom stylesheets. To re-enable them, exit Firefox and launch
through `archcfg-firefox`; the installed template restores the preference and CSS.

## Checks after Firefox updates

- Confirm that the expected profile is active using `about:support`.
- Check browser tabs, toolbar controls and focus outlines.
- Open the history sidebar and a new private window; check square search fields,
  history cards, and the private page's navy/blue colors.
- Check session restoration when that page is available, plus a PDF's toolbar,
  menus and dialogs. Verify blue accents, square controls and legible text.
- If only internal pages regress, inspect `userContent.css`, its stylesheet-link
  selectors and the installed Firefox design tokens. Do not assume that changing
  `userChrome.css` will affect those pages.
- Compare the repository, installed template and active profile copies.

From the repository root, run:

```sh
bash -n packages/firefox/archcfg-firefox
git diff --check -- packages/firefox
```

Run ShellCheck on the launcher when available. Syntax checks do not replace
visual verification after a full browser restart.

On 2026-10-05, CSS parsing, launcher syntax, deployment-copy equality and
`git diff --check` passed for the internal-page fix. Ricardo confirmed that it
worked after restarting Firefox. Browser profiles and runtime data remain outside
Git; see the [configuration inventory](../../docs/configuration-inventory.md).
