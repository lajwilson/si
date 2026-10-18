# si

Fast, readable Linux server inventory script. Non-root, zero-install, distro-aware.

## Disclaimer

**THIS SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.**

This is a read-only inventory tool. It does not modify the system. You are solely responsible for how and where you run it. Use at your own risk.

## Usage

```bash
curl -fsSL https://raw.githubusercontent.com/lajwilson/si/main/si.sh | bash
```

Or download and run locally:

```bash
curl -fsSL https://raw.githubusercontent.com/lajwilson/si/main/si.sh -o si.sh
bash si.sh
```

## What it does

- Detects Linux distribution family (Debian, RHEL, Arch, SUSE, Alpine, etc.)
- Collects identity, hardware, disk, network, listening ports, processes, users, packages, services, containers, and environment
- Runs as a non-root user with no package installs
- Produces a clean, readable summary

## Limitations

- Linux only (not macOS, BSD, or Windows)
- Non-root: some system details are intentionally limited
- Relies on common Linux tools (`ps`, `ss`/`netstat`, `df`, `/proc`, etc.)

## License

MIT License — see [LICENSE](LICENSE).

Public use is allowed under the MIT license. No warranty is provided.