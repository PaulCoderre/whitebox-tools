To run NCAmapper, first use this apptainer: ~/containers/geospatial_4.4.0.sif

Whitebox Fix
The issue is that the built in parallization waits for prompts, and not that the jobs are finished which leads to reading and writing conflicts. 
thread::spawn() returns a JoinHandle, but it's discarded — never .join()'d. The code only waits for rx.recv() to receive the pits vector via the channel. But sending a message via tx.send() doesn't mean the spawned thread has finished executing and dropped its Arc clone — that's a separate, racy event governed by OS thread scheduling/cleanup.
Arc::try_unwrap() only succeeds if the strong reference count is exactly 1. If any spawned thread's stack frame (holding its Arc clone) hasn't been torn down yet at the moment the main thread calls try_unwrap, the count is > 1, try_unwrap returns Err, and the code panics.

1.	Install rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source "$HOME/.cargo/env"
rustc --version  # confirm it works
2.	Clone repository 
https://github.com/jblindsay/whitebox-tools.git

3.	Fix code in depth_in_sink.rs, sink.rs and fill_depressions.rs
Replace: 
let filled_dem2 = Arc::new(filled_dem); let (tx, rx) = mpsc::channel(); for tid in 0..num_procs { let filled_dem2 = filled_dem2.clone(); let tx = tx.clone(); thread::spawn(move || {
With: 
let filled_dem2 = Arc::new(filled_dem);
let (tx, rx) = mpsc::channel();

let mut handles = Vec::with_capacity(num_procs as usize);
for tid in 0..num_procs {
    let filled_dem2 = filled_dem2.clone();
    let tx = tx.clone();
    handles.push(thread::spawn(move || {

and add 
// Ensure all spawned threads (and their Arc clones) have fully exited // before attempting Arc::try_unwrap — fixes a race condition that // causes intermittent "Error unwrapping 'filled_dem'" panics. for h in handles { h.join().expect("Thread panicked"); } 

4.	Compile
a.	Dependencies: Problem with cargo not matching, regenerating it worked. 
mv Cargo.lock Cargo.lock.bak 
cargo generate-lockfile 
cargo fetch

b.	Compile whitebox_tools
apptainer exec --bind $(pwd):/work --pwd /work ~/containers/geospatial_4.4.0.sif \
  bash -c 'source ~/.cargo/env && cargo build --release --offline -j 4 -p whitebox_tools' 2>&1 | tee fresh_build.log | tail -40

5.	Test
a.	Create test dir 
mkdir -p ~/wbt_fixed_test 
cp ~/wbt_fixed/target/release/whitebox_tools ~/wbt_fixed_test/ 
cp ~/.local/share/R/whitebox/WBT/settings.json ~/wbt_fixed_test/ 2>/dev/null 
chmod +x ~/wbt_fixed_test/whitebox_tools
apptainer exec ~/containers/geospatial_4.4.0.sif ~/wbt_fixed_test/whitebox_tools --version

