## vm -- Manage KVM/QEMU virtual machines

There are [many](https://www.linux-kvm.org/page/Management_Tools) KVM
management tools out there. This one is mine.

It is primarily intended to support the use case of running throwaway KVM/QEMU
VMs (_not_ unikernels) for a CI system (see `examples/`). An eventual secondary
use case is to provide a comfortable CLI for throwaway VM management on a
development machine.

Therefore, it:

- is strictly opinionated and minimalist,
- only tested on Debian GNU/Linux 9.x as a host system,
- only supports LVM with thin provisioning for storage,
- only supports macvtap for networking,
- assumes that the underlying network is an isolated VLAN with DHCP and DNS
  service provided elsewhere.

## Installation

### Dependencies

- Debian GNU/Linux 9.x `x86_64` as a host system.
- LVM, `thin-provisioning-tools`, `socat`, `qemu-system-x86`.

### Rough steps

This is for an install from scratch, as root:

- `mkdir -p /etc/vm/vm.d`
- `mkdir -p /var/lib/vm/chroot`
- `cp config.sh.dist /etc/vm/config.sh`, edit to suit.
- `make install`

## Known issues/caveats

- Not much documentation, but the `vm` commands should be self-explanatory.
- `vm create` and `vm clone` _should_ be safe to execute in parallel, but this
  has not (yet) been extensively tested under load. All other _VM-specific_
  operations on the same VM should not be called in parallel.
- The current network setup relies on an undocumented external dnsmasq
  configuration, I'd like to replace this with a MirageOS unikernel.

