# Oracle A1 deployment

The React site runs on Vercel. One Ubuntu Arm VM runs the Java Backend, both Python services, and Caddy. Only Caddy publishes ports; it provides HTTPS and forwards WebSocket upgrades to the Backend.

## Create the VM

1. Sign up for [Oracle Cloud Always Free](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm). Most sign-ups require a card for verification.
2. Create an **Ubuntu aarch64** `VM.Standard.A1.Flex` instance with **2 OCPU and 12 GB RAM** in the home region. Save the SSH private key. A 50 GB boot volume is enough to start; Oracle's Always Free block allowance is 200 GB including boot volumes.
3. Give the VM a public IPv4 address. In its VCN security list or network security group, permit inbound TCP **80** and **443** from the internet and SSH **22** from your own IP. The bootstrap also opens 80/443 in Ubuntu's host iptables rules.
4. If A1 capacity is unavailable, try another availability domain in the home region or retry later. Oracle [may reclaim idle VMs](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm) if CPU, network, and memory each stay below 20% over seven days; keep a copy of checkpoints and deployment configuration off-VM.

## Stage the kit and checkpoints

Create the Vercel project first if needed to learn its production URL; the initial frontend build can be redeployed after the Backend is online. Make `deploy/oracle/.env` from `.env.example`. Set `REPO_URL` to the repository URL and `RFSCHEDULER_ALLOWED_ORIGINS` to the final Vercel origin, for example `https://your-project.vercel.app`. Leave `PUBLIC_HOST` blank to obtain `<public-ip-with-dashes>.sslip.io` through [sslip.io DNS](https://nip.io/), or set a hostname you control whose DNS points to the VM. A private repository needs a read-only deploy key or another authorized Git credential on the VM.

From the local `sih` directory, the deployment operator runs:

```sh
scp -r deploy/oracle ubuntu@VM_IP:~/oracle-deploy
ssh ubuntu@VM_IP 'mkdir -p ~/oracle-deploy/checkpoints'
scp -r Ai-ml-1-Scheduler-Engine/ml/checkpoints/. ubuntu@VM_IP:~/oracle-deploy/checkpoints/
ssh ubuntu@VM_IP 'bash ~/oracle-deploy/deploy.sh'
```

The script installs Docker Engine and Compose, opens the host firewall, clones or fast-forwards `master` with `GIT_LFS_SKIP_SMUDGE=1` so video assets are not downloaded, copies the checkpoint registry and weights into the ignored `deploy/oracle/checkpoints/` bind mount, builds Arm images, starts the stack, and waits for `https://PUBLIC_HOST/health`. Re-run the script after a code update. Keep `.env` and checkpoints in the staging directory for repeat deployments. The script intentionally refuses to start without `index.json`.

## Connect Vercel

Import the repository as a Vercel Vite project with root directory `Frontend`, build command `npm run build`, and output directory `dist`. Set the Production build environment variable `VITE_API_BASE=https://PUBLIC_HOST` with **no trailing slash**. The Frontend uses this for REST and derives `wss://PUBLIC_HOST/ws/v1/simulations/...` for live frames. Vite embeds the value at build time, so redeploy after changing it. `Frontend/vercel.json` sends SPA deep links to `index.html`.

Confirm the Vercel production origin matches `RFSCHEDULER_ALLOWED_ORIGINS` in the VM `.env`; rerun the bootstrap when that origin changes. Vercel preview deployments have different origins and need to be added explicitly if they must reach the API.

## Limits

The default Backend profile uses **in-memory H2**. Experiment and simulation records vanish when the Backend container restarts or is rebuilt. The two Python services also keep simulation session state in memory. Checkpoints persist in the bind mount and Caddy certificates in the named volume. The public API currently defaults to unauthenticated demo access; restrict access or enable the project's auth flow before sharing the URL widely. Arm compatibility and actual memory/CPU load must be validated on the VM, especially the PyTorch image; the Dockerfiles have not yet been built on A1 hardware.
