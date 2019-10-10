#define _GNU_SOURCE
#include <assert.h>
#include <err.h>
#include <errno.h>
#include <fcntl.h>
#include <linux/if.h>
#include <linux/if_tun.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

/*
 * Create a tap interface. Returns 0 if successful, system errno if not.
 *
 * If fd_out is NULL then creates a persistent interface, otherwise
 * returns the tap fd as *fd_out.
 */
static int create_tap_link(const char *name, int *fd_out)
{
    struct ifreq ifr;
    int fd;

    if (strlen(name) >= IFNAMSIZ)
        return ENAMETOOLONG;

    fd = open("/dev/net/tun", O_RDWR);
    if (fd < 0)
        return errno;

    ifr.ifr_flags = IFF_TAP | IFF_NO_PI;
    strncpy(ifr.ifr_name, name, IFNAMSIZ - 1);
    if (ioctl(fd, TUNSETIFF, &ifr) < 0)
        return errno;

    if (fd_out) {
        *fd_out = fd;
    } else {
        if (ioctl(fd, TUNSETPERSIST, 1) < 0)
            return errno;

        close(fd);
    }

    return 0;
}

int main(int argc, char *argv[])
{
    if (argc < 3)
        errx(1, "usage: tap_attach INTERFACE COMMAND [ ARGS ... ]");
    
    int fd = -1;
    int rc;

    rc = create_tap_link(argv[1], &fd);
    if (rc != 0)
        err(1, "create_tap_link(%s)", argv[1]);
    assert(fd == 3);
    
    argv += 2;
    argc -= 2;
    char path[strlen(argv[0]) + 1];
    strcpy(path, argv[0]);
    argv[0] = basename(argv[0]);
    assert(*argv[0]);
    rc = execvp(path, argv);
    if (rc != 0)
        err(1, "execv(%s)", path);
}
