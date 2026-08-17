import { FileUtil, Json5Reader } from '@ohos/hvigor';
import { appTasks } from '@ohos/hvigor-ohos-plugin';

const localSigningPath: string = '.signing/local-signing.json';
const localSigningFile: Record<string, object | string> | undefined = FileUtil.exist(localSigningPath)
  ? Json5Reader.getJson5Obj(localSigningPath) as Record<string, object | string>
  : undefined;
const localSigningConfig: object | undefined = localSigningFile === undefined ? undefined : {
  type: localSigningFile.type,
  material: localSigningFile.material
};

export default {
  system: appTasks,
  plugins: [],
  // Signing material is machine-specific. Hvigor accepts it as an in-memory
  // override, so DevEco Run can sign without putting paths/passwords in Git.
  config: {
    ohos: localSigningConfig === undefined ? undefined : {
      overrides: {
        signingConfig: localSigningConfig
      }
    }
  }
}
