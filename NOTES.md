iptables -t nat -F
ip link set docker0 down
ip link delete docker0

https://github.com/kubernetes/kubernetes/issues/26038

add cgroup_enable=cpuset to /boot/cmdline.txt


Run netutils container:

```
kubectl run netutils --image danisla/rpi-netutils --replicas=2 --command -- /bin/bash -c "while true; do sleep 1000; done"
```
