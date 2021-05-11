import typescript from '@rollup/plugin-typescript';
import { terser } from "rollup-plugin-terser";

export default {
	input: 'src/index.ts',
  treeshake: false,
	output: {
		file: 'build/index.min.js',
		format: 'cjs',
		esModule: false,
		sourcemap: false,
    strict: false,
		preferConst: true,
		exports: 'none'
	},
  plugins: [typescript(), terser({toplevel: false})]
};