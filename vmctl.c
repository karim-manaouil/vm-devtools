#include <stdlib.h>
#include <stdio.h>
#include <fcntl.h>
#include <errno.h>
#include <unistd.h>
#include <string.h>

int handle_arguments(char *key[64], char *value[64], int nr_keys)
{	
	int vmctl_wait = 0;
	char *vmctl_cmd;
	char ip_addr_fmt[] = "ip address add %s/24 dev enp0s4";
	char ip_link_fmt[] = "ip link set enp0s4 up";
	char syscmd[1024];	
	char *p;
	int i;

	for (i = 0; i < nr_keys; i++) {
		if (!strcmp(key[i], "vmctl_ip")) {
			printf("Setting network up with ip %s\n", value[i]);
			snprintf(syscmd, 1024, ip_addr_fmt, value[i]);
			system(syscmd);
			system(ip_link_fmt);
		} else if (!strcmp(key[i], "vmctl_wait")) {
			vmctl_wait = atoi(value[i]); 
		} else if (!strcmp(key[i], "vmctl_cmd")) {
			vmctl_cmd = value[i];
			while ((p = strchr(vmctl_cmd, '#')))
				*p = ' ';		
		}
	}	
	printf("Executing %s\n", vmctl_cmd);
	system(vmctl_cmd);

	printf("Waiting for %d\n", vmctl_wait);
	snprintf(syscmd, 1024, "sleep %d", vmctl_wait);
	system(syscmd);

	return 0;
}

int parse_cmdline(char *cmdline, char *end)
{
	char *p = cmdline;
	char *key[64] = {0}, *value[64] = {0};
	int idx = 0;
	char delm;

	while (p < end) {
		//printf("now at %s\n", p);
		key[idx] = p;
		while (p < end && *p != '=' && *p != ' ')
			p++;
		if (p == end)
			goto end_parsing;

		if (*p == ' ') { /* only key, no value */
			*p++ = 0;
			goto next;
		} else {
			*p++ = 0;

			if (*p == '\'') {
				value[idx] = ++p;
				delm = '\'';
			} else {
				value[idx] = p;
				delm = ' ';
			}

			while (p < end && *p != delm)
				p++;
			if (p == end)
				goto end_parsing;
			*p++ = 0;
		}
next:
		while (p < end && *p == ' ') /* Skip spaces */
			p++;
end_parsing:
		idx++;
	}
	
	handle_arguments(key, value, idx);
	
	return 0;
}

int main()
{
	char cmdline[4096]= {0};
	ssize_t nbytes;
	int fd;
	char *newl;

	fd = open("/proc/cmdline", O_RDONLY);
	if (fd == -1) {
		perror("open:");
		exit(1);	
	}

	nbytes = read(fd, cmdline, 4096);
	if (nbytes < 0) {
		perror("read:");
		exit(1);
	}
	newl = strchr(cmdline, '\n');	
	parse_cmdline(cmdline, newl);

	return 0;
}
