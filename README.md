## vm -- Manage KVM/QEMU virtual machines

There are [many](https://www.linux-kvm.org/page/Management_Tools) KVM
management tools out there. This one is mine.

It is primarily intended to support the use case of running throwaway KVM/QEMU
VMs (_not_ unikernels) for a CI system (see `examples/`). An eventual secondary
use case is to provide a comfortable CLI for throwaway VM management on a
development machine.

Therefore, it:

- is strictly opinionated and minimalist,
- only tested on Debian GNU/Linux 10.x as a host system,
- only supports LVM with thin provisioning for storage,
- only supports macvtap or bridged networking,
- assumes that the underlying network is an isolated VLAN with DHCP and DNS
  service provided elsewhere.

## Installation

### Dependencies

- Debian GNU/Linux 10.x `x86_64` as a host system.
- LVM, `thin-provisioning-tools`, `socat`, `qemu-system-x86`.
- `ssvnc` (optional).

### Rough steps

This is for an install from scratch, as root:

```sh
make
sudo make install
# READ and edit the script to suit (at least changing the volume group name)
sudo ./install.sh
# READ and edit /etc/vm/config.sh (at least changing the volume group name)
```

The defaults are to use `bridge` mode for networking, using `vmbr0`. For an
example of how to set up `vmbr0`, see [examples/vmbr0](examples/vmbr0).

For `vm console` to work directly on the host, install `ssvnc`.  If you
only need to access consoles via the SSH forwarding functionality, copy
`src/vm-console.sh` to your client host and install `ssvnc` there. In
either case, you do not need the JRE dependency of `ssvnc`.

## Known issues/caveats

- Not much documentation, but the `vm` commands should be self-explanatory.
- Due to the need to manipulate LVM volumes, most `vm` commands must be run as
  root.
- `vm create` and `vm clone` _should_ be safe to execute in parallel, but this
  has not (yet) been extensively tested under load. All other _VM-specific_
  operations on the same VM should not be called in parallel.
- The current network setup relies on an undocumented external dnsmasq
  configuration, I'd like to replace this with a MirageOS unikernel.
