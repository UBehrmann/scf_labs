#ifndef __IOCTL_CMDS_H__
#define __IOCTL_CMDS_H__

#ifdef __KERNEL__
#include <linux/ioctl.h>
#include <linux/types.h>
typedef __u32 scf_u32_t;
#else
#include <sys/ioctl.h>
#include <stdint.h>
typedef uint32_t scf_u32_t;
#endif

#define SCF_IOC_MAGIC  's'

#define IOCTL_SCF_RESET       _IO(SCF_IOC_MAGIC, 0)
#define IOCTL_SCF_GET_STATUS  _IOR(SCF_IOC_MAGIC, 1, scf_u32_t)
#define IOCTL_SCF_SET_PARAMS  _IOW(SCF_IOC_MAGIC, 2, struct scf_params)

struct scf_params {
	scf_u32_t p0;
	scf_u32_t p1;
	scf_u32_t p2;
};

#endif
