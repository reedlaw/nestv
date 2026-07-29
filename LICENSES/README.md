# Licenses

Except where a file or directory says otherwise, original nestv material is
licensed under the GNU General Public License, version 3 or (at your option)
any later version (`GPL-3.0-or-later`).

The complete GPL-3.0 license text is included by the pinned NESTang submodule
at `rtl/core/nestang/COPYING`. It is also available from
<https://www.gnu.org/licenses/gpl-3.0.txt>.

Third-party components retain their upstream licenses and copyright notices:

- NESTang is GPL-3.0 and includes its license in
  `rtl/core/nestang/COPYING`.
- The unchanged `yc_out.sv` source identifies itself as
  GPL-2.0-or-later. `make bootstrap` downloads the license supplied by its
  pinned upstream repository to `build/upstream/COPYING`.
- TangCore is not currently fetched. If it is added for M5, its Apache-2.0
  firmware and separately licensed bundled cores will retain their respective
  terms.

See `THIRD_PARTY.md` for each dependency's source, immutable revision, and
use in this project.
