import subprocess
import random
import time

types = ['base']
classes = {
        "small": {"vcpu": 8, "memory": 4},
        "medium": {"vcpu": 16, "memory": 8},
        "large": {"vcpu": 32, "memory": 64},
        }
commands = {
        "small": ['/root/omp/bin/bt.C.x'],
        "medium": ['/root/omp/bin/bt.C.x', 'docker#run#--rm#kubeflowkatib/pytorch-mnist'],
        "large": ['/root/omp/bin/bt.D.x', 'docker#run#--rm#kubeflowkatib/pytorch-mnist'],
        }
wait_times = [1, 5, 10, 30, 60, 300, 600]  # Seconds

def generate_vm_parameters():
        for instance in range(1, 11):  # Instance count from 1 to 10
            vm_type = random.choice(types)
            vm_class = random.choice(list(classes.keys()))
            command = random.choice(commands[vm_class])
            base_image_name = f"{vm_type}-{instance}"
            tap_device = f"tap{instance}"
            ip_address = f"192.168.100.{10 + instance}"
            wait_time = random.choice(wait_times)
            yield {'vm_type': vm_type, 'vm_class': vm_class, 'instance': instance, 'base_image_name': base_image_name,
                   'tap_device': tap_device, 'ip_address': ip_address, 'command': command, 'wait_time': wait_time}

def create_vm(vm_type, vm_class, instance, base_image_name, tap_device, ip_address, command, wait_time):
    print("VM Type:", vm_type)
    print("VM Class:", vm_class)
    print("Instance:", instance)
    print("Base Image Name:", base_image_name)
    print("Tap Device:", tap_device)
    print("IP Address:", ip_address)
    print("Command:", command)
    print("Wait Time:", wait_time)

    vcpu = classes[vm_class]["vcpu"]
    memory = classes[vm_class]["memory"]

    command_line = f"sudo ./vmctl.sh start {vcpu} {memory} ../sdb/images/{base_image_name} {tap_device} {ip_address} {command} {wait_time} 2>/dev/null"
    print(command_line)
    subprocess.run(command_line, shell=True)
def main():
    for vm_params in generate_vm_parameters():
        create_vm(**vm_params)
        time.sleep(1)

if __name__ == "__main__":
    main()
