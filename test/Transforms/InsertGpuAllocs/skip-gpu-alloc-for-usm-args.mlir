// RUN: imex-opt --insert-gpu-allocs='client-api=opencl is-usm-args=1' %s | FileCheck %s --check-prefix=OPENCL
// RUN: imex-opt --insert-gpu-allocs='client-api=vulkan is-usm-args=1' %s | FileCheck %s --check-prefix=VULKAN

// OPENCL-LABEL: func.func @addt
// OPENCL-SAME:  %[[arg0:.+]]: memref<2x5xf32>, %[[arg1:.+]]: memref<2x5xf32>, %[[out_buff:.+]]: memref<2x5xf32>
// VULKAN-LABEL: func.func @addt
// VULKAN-SAME:  %[[arg0:.+]]: memref<2x5xf32>, %[[arg1:.+]]: memref<2x5xf32>, %[[out_buff:.+]]: memref<2x5xf32>
func.func @addt(%arg0: memref<2x5xf32>, %arg1: memref<2x5xf32>, %out_buff: memref<2x5xf32>) -> memref<2x5xf32> {
  %c0 = arith.constant 0 : index
  %c2 = arith.constant 2 : index
  %c1 = arith.constant 1 : index
  %c5 = arith.constant 5 : index
  // OPENCL-NOT: %[[MEMREF0:.*]] = gpu.alloc host_shared () : memref<2x5xf32>
  // OPENCL-NOT: %[[MEMREF1:.*]] = gpu.alloc host_shared () : memref<2x5xf32>
  // OPENCL-NOT: memref.copy
  // OPENCL-NOT: %[[MEMREF2:.*]] = gpu.alloc host_shared () : memref<2x5xf32>
  // OPENCL-NOT: memref.copy

  // VULKAN-NOT: %[[MEMREF0:.*]] = memref.alloc() : memref<2x5xf32>
  // VULKAN-NOT: %[[MEMREF1:.*]] = memref.alloc() : memref<2x5xf32>
  // VULKAN-NOT: memref.copy
  // VULKAN-NOT: %[[MEMREF2:.*]] = memref.alloc() : memref<2x5xf32>
  // VULKAN-NOT: memref.copy

  %tmp_buff = memref.alloc() {alignment = 128 : i64} : memref<2x5xf32>
  // OPENCL-NOT:  %[[MEMREF3:.*]] = memref.alloc().*
  // OPENCL:  %[[MEMREF3:.*]] = gpu.alloc () : memref<2x5xf32>
  // VULKAN:  %[[MEMREF3:.*]] = memref.alloc() {alignment = 128 : i64} : memref<2x5xf32>

  %c1_0 = arith.constant 1 : index
  %1 = affine.apply affine_map<(d0)[s0, s1] -> ((d0 - s0) ceildiv s1)>(%c2)[%c0, %c1]
  %2 = affine.apply affine_map<(d0)[s0, s1] -> ((d0 - s0) ceildiv s1)>(%c5)[%c0, %c1]
  gpu.launch blocks(%arg2, %arg3, %arg4) in (%arg8 = %1, %arg9 = %2, %arg10 = %c1_0) threads(%arg5, %arg6, %arg7) in (%arg11 = %c1_0, %arg12 = %c1_0, %arg13 = %c1_0) {
    %3 = affine.apply affine_map<(d0)[s0, s1] -> (d0 * s0 + s1)>(%arg2)[%c1, %c0]
    %4 = affine.apply affine_map<(d0)[s0, s1] -> (d0 * s0 + s1)>(%arg3)[%c1, %c0]
    %5 = memref.load %arg0[%3, %4] : memref<2x5xf32>
    %6 = memref.load %arg1[%3, %4] : memref<2x5xf32>
    %7 = arith.addf %5, %6 : f32
    memref.store %7, %tmp_buff[%3, %4] : memref<2x5xf32>

    %8 = memref.load %tmp_buff[%3, %4] : memref<2x5xf32>
    %9 = arith.addf %8, %5 : f32
    memref.store %9, %out_buff[%3, %4] : memref<2x5xf32>

    gpu.terminator
  } {SCFToGPU_visited}

  // OPENCL-NOT: memref.dealloc %[[MEMREF3]] : memref<2x5xf32>
  // OPENCL: gpu.dealloc %[[MEMREF3]] : memref<2x5xf32>
  // VULKAN: memref.dealloc %[[MEMREF3]] : memref<2x5xf32>
  memref.dealloc %tmp_buff : memref<2x5xf32>

  return %out_buff : memref<2x5xf32>
}
