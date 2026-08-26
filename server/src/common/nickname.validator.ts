import {
  ValidatorConstraint,
  ValidatorConstraintInterface,
} from 'class-validator';

/** 昵称显示宽度：中文（CJK）/全角字符按 2 计，其余按 1 计（30 个西文字符 ≈ 16 个汉字） */
export function nicknameUnitLength(value: string): number {
  let units = 0;
  for (const ch of value) {
    const code = ch.codePointAt(0) ?? 0;
    // CJK 统一表意（含扩展 A）、日文假名、韩文、全角标点/字母数字
    const isWide =
      (code >= 0x2e80 && code <= 0x9fff) ||
      (code >= 0x3000 && code <= 0x303f) ||
      (code >= 0x3040 && code <= 0x30ff) ||
      (code >= 0xac00 && code <= 0xd7af) ||
      (code >= 0xff00 && code <= 0xff60) ||
      (code >= 0xffe0 && code <= 0xffe6);
    units += isWide ? 2 : 1;
  }
  return units;
}

/**
 * 昵称规则：最多 30 个字符（含中文），且显示宽度不超过 32（即纯汉字最多 16 个）。
 * 与客户端注册/资料页保持一致。
 */
export function isNicknameValid(value: string): boolean {
  return value.length <= 30 && nicknameUnitLength(value) <= 32;
}

@ValidatorConstraint({ name: 'isValidNickname', async: false })
export class IsValidNickname implements ValidatorConstraintInterface {
  validate(value: string): boolean {
    return isNicknameValid(value ?? '');
  }

  defaultMessage(): string {
    return '昵称最多 30 个字符（1 个汉字按 2 个计，最多 16 个汉字）';
  }
}
