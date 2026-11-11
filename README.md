# vehicle_ws (ros1-noetic)

ROS 1 noetic workspace for the Avante CN7, built from the `ros1-noetic` branches of
`vehicle_can_common` and `avante_cn7_interface`. This branch is an archive of the ROS 1 port and
is never merged into `main` (ROS 2 only).

## Layout

| Path | Content |
|---|---|
| `repos/avante_cn7.repos` | source repositories (`vcs import`) |
| `scripts/install_deps.sh` | everything the workspace needs on top of ROS (apt, dbcppp, pip) |
| `requirements.txt` | pip packages missing from focal apt (web tool) |
| `scripts/can_up.sh` | bring up `can0` / `vcan0` |
| `docker/` | dev image (Ubuntu 20.04 + noetic desktop-full) and compose file |

## Vehicle PC (no docker)

Ubuntu 20.04 with `ros-noetic-desktop-full` installed.

```bash
git clone -b ros1-noetic https://github.com/junhyeok797/vehicle_ws.git ~/vehicle_ws
cd ~/vehicle_ws
scripts/install_deps.sh            # BUILD_JOBS=4 by default
rosdep update
mkdir -p src && vcs import --recursive src < repos/avante_cn7.repos
source /opt/ros/noetic/setup.bash
catkin init
# -j4 -p1: 4 compile jobs, one package at a time (the default uses every core and can run
# out of RAM); stored in the profile, so a plain `catkin build` keeps it.
catkin config --extend /opt/ros/noetic -j 4 -p 1 --cmake-args -DCMAKE_BUILD_TYPE=Release
catkin build
source devel/setup.bash
```

dbcppp is installed into `/opt/dbcppp`, not `/usr/local`: it ships its own libxml2, which
would otherwise shadow the system one. `find_package(libdbcppp)` finds it through
`/usr/local/lib/cmake/libdbcppp`.

## Dev PC (docker)

Needs Docker Compose v2 and the NVIDIA Container Toolkit.

```bash
cd vehicle_ws
mkdir -p src && vcs import --recursive src < repos/avante_cn7.repos   # or git clone by hand
xhost +local:
HOST_UID=$(id -u) HOST_GID=$(id -g) docker compose -f docker/compose.yaml up -d --build
docker compose -f docker/compose.yaml exec dev bash
```

Inside the container the workspace is `~/vehicle_ws`; build it as on the vehicle PC (from
`catkin init`). `CAN_LOG_DIR=/path/to/logs` mounts candump logs at `~/can_logs`.
`BUILD_JOBS` (default 4) sets the compile jobs of the image build and `MEM_LIMIT` (default
16g) caps the container RAM; raise them on a PC with more memory.

## Tests

```bash
catkin build --catkin-make-args run_tests && catkin_test_results build
```

## Log replay

```bash
# web tool straight from a candump log (http://localhost:8080)
rosrun vehicle_can_web vehicle_can_web --vehicle avante_cn7_interface --replay ~/can_logs/<log>.log

# or through vcan0, the same path as the live bus
scripts/can_up.sh vcan0
canplayer -I ~/can_logs/<log>.log can0=vcan0 &
rosrun vehicle_can_web vehicle_can_web --vehicle avante_cn7_interface --set bus.main=vcan0
```
