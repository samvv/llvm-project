// RUN: mlir-opt %s -convert-vector-to-scf -lower-affine -convert-scf-to-std -convert-vector-to-llvm -convert-std-to-llvm | \
// RUN: mlir-cpu-runner -e entry -entry-point-result=void  \
// RUN:   -shared-libs=%mlir_integration_test_dir/libmlir_c_runner_utils%shlibext | \
// RUN: FileCheck %s

// RUN: mlir-opt %s -convert-vector-to-scf=full-unroll=true -lower-affine -convert-scf-to-std -convert-vector-to-llvm -convert-std-to-llvm | \
// RUN: mlir-cpu-runner -e entry -entry-point-result=void  \
// RUN:   -shared-libs=%mlir_integration_test_dir/libmlir_c_runner_utils%shlibext | \
// RUN: FileCheck %s

// Test for special cases of 1D vector transfer ops.

memref.global "private" @gv : memref<5x6xf32> =
    dense<[[0. , 1. , 2. , 3. , 4. , 5. ],
           [10., 11., 12., 13., 14., 15.],
           [20., 21., 22., 23., 24., 25.],
           [30., 31., 32., 33., 34., 35.],
           [40., 41., 42., 43., 44., 45.]]>

// Non-contiguous, strided load.
func @transfer_read_1d(%A : memref<?x?xf32>, %base1 : index, %base2 : index) {
  %fm42 = constant -42.0: f32
  %f = vector.transfer_read %A[%base1, %base2], %fm42
      {permutation_map = affine_map<(d0, d1) -> (d0)>}
      : memref<?x?xf32>, vector<9xf32>
  vector.print %f: vector<9xf32>
  return
}

// Broadcast.
func @transfer_read_1d_broadcast(
    %A : memref<?x?xf32>, %base1 : index, %base2 : index) {
  %fm42 = constant -42.0: f32
  %f = vector.transfer_read %A[%base1, %base2], %fm42
      {permutation_map = affine_map<(d0, d1) -> (0)>}
      : memref<?x?xf32>, vector<9xf32>
  vector.print %f: vector<9xf32>
  return
}

// Non-contiguous, strided load.
func @transfer_read_1d_in_bounds(
    %A : memref<?x?xf32>, %base1 : index, %base2 : index) {
  %fm42 = constant -42.0: f32
  %f = vector.transfer_read %A[%base1, %base2], %fm42
      {permutation_map = affine_map<(d0, d1) -> (d0)>, in_bounds = [true]}
      : memref<?x?xf32>, vector<3xf32>
  vector.print %f: vector<3xf32>
  return
}

// Non-contiguous, strided load.
func @transfer_read_1d_mask(
    %A : memref<?x?xf32>, %base1 : index, %base2 : index) {
  %fm42 = constant -42.0: f32
  %mask = constant dense<[1, 0, 1, 0, 1, 1, 1, 0, 1]> : vector<9xi1>
  %f = vector.transfer_read %A[%base1, %base2], %fm42, %mask
      {permutation_map = affine_map<(d0, d1) -> (d0)>}
      : memref<?x?xf32>, vector<9xf32>
  vector.print %f: vector<9xf32>
  return
}

// Non-contiguous, strided load.
func @transfer_read_1d_mask_in_bounds(
    %A : memref<?x?xf32>, %base1 : index, %base2 : index) {
  %fm42 = constant -42.0: f32
  %mask = constant dense<[1, 0, 1]> : vector<3xi1>
  %f = vector.transfer_read %A[%base1, %base2], %fm42, %mask
      {permutation_map = affine_map<(d0, d1) -> (d0)>, in_bounds = [true]}
      : memref<?x?xf32>, vector<3xf32>
  vector.print %f: vector<3xf32>
  return
}

// Non-contiguous, strided store.
func @transfer_write_1d(%A : memref<?x?xf32>, %base1 : index, %base2 : index) {
  %fn1 = constant -1.0 : f32
  %vf0 = splat %fn1 : vector<7xf32>
  vector.transfer_write %vf0, %A[%base1, %base2]
    {permutation_map = affine_map<(d0, d1) -> (d0)>}
    : vector<7xf32>, memref<?x?xf32>
  return
}

// Non-contiguous, strided store.
func @transfer_write_1d_mask(%A : memref<?x?xf32>, %base1 : index, %base2 : index) {
  %fn1 = constant -2.0 : f32
  %vf0 = splat %fn1 : vector<7xf32>
  %mask = constant dense<[1, 0, 1, 0, 1, 1, 1]> : vector<7xi1>
  vector.transfer_write %vf0, %A[%base1, %base2], %mask
    {permutation_map = affine_map<(d0, d1) -> (d0)>}
    : vector<7xf32>, memref<?x?xf32>
  return
}

func @entry() {
  %c0 = constant 0: index
  %c1 = constant 1: index
  %c2 = constant 2: index
  %c3 = constant 3: index
  %0 = memref.get_global @gv : memref<5x6xf32>
  %A = memref.cast %0 : memref<5x6xf32> to memref<?x?xf32>

  // 1. Read from 2D memref on first dimension. Cannot be lowered to an LLVM
  //    vector load. Instead, generates scalar loads.
  call @transfer_read_1d(%A, %c1, %c2) : (memref<?x?xf32>, index, index) -> ()
  // CHECK: ( 12, 22, 32, 42, -42, -42, -42, -42, -42 )

  // 2. Write to 2D memref on first dimension. Cannot be lowered to an LLVM
  //    vector store. Instead, generates scalar stores.
  call @transfer_write_1d(%A, %c3, %c2) : (memref<?x?xf32>, index, index) -> ()

  // 3. (Same as 1. To check if 2 works correctly.)
  call @transfer_read_1d(%A, %c0, %c2) : (memref<?x?xf32>, index, index) -> ()
  // CHECK: ( 2, 12, 22, -1, -1, -42, -42, -42, -42 )

  // 4. Read a scalar from a 2D memref and broadcast the value to a 1D vector.
  //    Generates a loop with vector.insertelement.
  call @transfer_read_1d_broadcast(%A, %c1, %c2)
      : (memref<?x?xf32>, index, index) -> ()
  // CHECK: ( 12, 12, 12, 12, 12, 12, 12, 12, 12 )

  // 5. Read from 2D memref on first dimension. Accesses are in-bounds, so no
  //    if-check is generated inside the generated loop.
  call @transfer_read_1d_in_bounds(%A, %c1, %c2)
      : (memref<?x?xf32>, index, index) -> ()
  // CHECK: ( 12, 22, -1 )

  // 6. Optional mask attribute is specified and, in addition, there may be
  //    out-of-bounds accesses.
  call @transfer_read_1d_mask(%A, %c1, %c2)
      : (memref<?x?xf32>, index, index) -> ()
  // CHECK: ( 12, -42, -1, -42, -42, -42, -42, -42, -42 )

  // 7. Same as 6, but accesses are in-bounds.
  call @transfer_read_1d_mask_in_bounds(%A, %c1, %c2)
      : (memref<?x?xf32>, index, index) -> ()
  // CHECK: ( 12, -42, -1 )

  // 8. Write to 2D memref on first dimension with a mask.
  call @transfer_write_1d_mask(%A, %c1, %c0)
      : (memref<?x?xf32>, index, index) -> ()

  // 9. (Same as 1. To check if 8 works correctly.)
  call @transfer_read_1d(%A, %c0, %c0) : (memref<?x?xf32>, index, index) -> ()
  // CHECK: ( 0, -2, 20, -2, 40, -42, -42, -42, -42 )

  return
}
