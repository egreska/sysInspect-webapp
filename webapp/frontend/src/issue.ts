export type IssuePath = { segments: string[] };

export const ISSUE_FLAGS = [
  'upright',
  'uprightFrontDamage',
  'uprightFrontTwisted',
  'uprightRearDamage',
  'uprightRearTwisted',
  'uprightAlignmentOutOfAlignment',
  'uprightAlignmentOutOfVerticalPlumb',
  'beam',
  'beamFrontDamage',
  'beamRearDamage',
  'beamFrontBowed',
  'beamRearBowed',
  'wireDeck',
  'wireDeckMissing',
  'wireDeckDamaged',
  'wireDeckOutOfPosition',
  'basePlate',
  'basePlateFloorDamaged',
  'basePlateTwisted',
  'basePlateDamaged',
  'anchors',
  'anchorsMissing',
  'anchorsDamaged',
  'anchorsTorqued',
  'bracingDamage',
  'bracingHorizontal',
  'bracingDiagonal',
  'postProtector',
  'postProtectorMissing',
  'postProtectorDamaged',
  'postProtectorRepairRequired',
  'aisleGuarding',
  'aisleGuardingMissing',
  'aisleGuardingDamaged',
  'aisleGuardingRepairRequired',
] as const;

export type IssueFlag = (typeof ISSUE_FLAGS)[number];
export type IssueFlagMap = Record<IssueFlag, boolean>;

type Node = {
  path: IssuePath;
  flag?: IssueFlag;
  children: Node[];
};

function n(segments: string[], flag?: IssueFlag, children: Node[] = []): Node {
  return { path: { segments }, flag, children };
}

const catalog: Node[] = [
  n(['Upright'], 'upright', [
    n(['Upright', 'Front'], undefined, [
      n(['Upright', 'Front', 'Damage'], 'uprightFrontDamage'),
      n(['Upright', 'Front', 'Twisted'], 'uprightFrontTwisted'),
    ]),
    n(['Upright', 'Rear'], undefined, [
      n(['Upright', 'Rear', 'Damage'], 'uprightRearDamage'),
      n(['Upright', 'Rear', 'Twisted'], 'uprightRearTwisted'),
    ]),
    n(['Upright', 'Alignment'], undefined, [
      n(['Upright', 'Alignment', 'Out of alignment'], 'uprightAlignmentOutOfAlignment'),
      n(['Upright', 'Alignment', 'Out of vertical plumb'], 'uprightAlignmentOutOfVerticalPlumb'),
    ]),
  ]),
  n(['Beam'], 'beam', [
    n(['Beam', 'Front damage'], 'beamFrontDamage'),
    n(['Beam', 'Rear damage'], 'beamRearDamage'),
    n(['Beam', 'Front bowed'], 'beamFrontBowed'),
    n(['Beam', 'Rear bowed'], 'beamRearBowed'),
  ]),
  n(['Wire Deck'], 'wireDeck', [
    n(['Wire Deck', 'Missing'], 'wireDeckMissing'),
    n(['Wire Deck', 'Damaged'], 'wireDeckDamaged'),
    n(['Wire Deck', 'Out of position'], 'wireDeckOutOfPosition'),
  ]),
  n(['Base Plate'], 'basePlate', [
    n(['Base Plate', 'Floor damaged'], 'basePlateFloorDamaged'),
    n(['Base Plate', 'Twisted'], 'basePlateTwisted'),
    n(['Base Plate', 'Damaged'], 'basePlateDamaged'),
  ]),
  n(['Anchors'], 'anchors', [
    n(['Anchors', 'Missing anchors or bolts'], 'anchorsMissing'),
    n(['Anchors', 'Damaged or bent'], 'anchorsDamaged'),
    n(['Anchors', 'Torqued to 35lbs'], 'anchorsTorqued'),
  ]),
  n(['Bracing Damage'], 'bracingDamage', [
    n(['Bracing Damage', 'Horizontal'], 'bracingHorizontal'),
    n(['Bracing Damage', 'Diagonal'], 'bracingDiagonal'),
  ]),
  n(['Post Protector'], 'postProtector', [
    n(['Post Protector', 'Missing'], 'postProtectorMissing'),
    n(['Post Protector', 'Damaged'], 'postProtectorDamaged'),
    n(['Post Protector', 'Repair required'], 'postProtectorRepairRequired'),
  ]),
  n(['Aisle Guarding'], 'aisleGuarding', [
    n(['Aisle Guarding', 'Missing'], 'aisleGuardingMissing'),
    n(['Aisle Guarding', 'Damaged'], 'aisleGuardingDamaged'),
    n(['Aisle Guarding', 'Repair required'], 'aisleGuardingRepairRequired'),
  ]),
];

function pathKey(path: IssuePath): string {
  return path.segments.join('\0');
}

function flattened(nodes: Node[] = catalog): Node[] {
  return nodes.flatMap((node) => [node, ...flattened(node.children)]);
}

function emptyFlags(): IssueFlagMap {
  return Object.fromEntries(ISSUE_FLAGS.map((flag) => [flag, false])) as IssueFlagMap;
}

function flagsFromPaths(selected: IssuePath[]): IssueFlagMap {
  const result = emptyFlags();
  const flagByPath = new Map<string, IssueFlag>();
  for (const node of flattened()) {
    if (node.flag) flagByPath.set(pathKey(node.path), node.flag);
  }
  for (const path of selected) {
    let current: IssuePath | null = path;
    while (current) {
      const flag = flagByPath.get(pathKey(current));
      if (flag) result[flag] = true;
      current =
        current.segments.length > 1
          ? { segments: current.segments.slice(0, -1) }
          : null;
    }
  }
  return result;
}

function selectedPaths(flags: IssueFlagMap): IssuePath[] {
  return flattened().flatMap((node) =>
    node.flag && flags[node.flag] ? [node.path] : []
  );
}

function bullet(path: IssuePath): string {
  return '• ' + path.segments.join(' > ');
}

function labelsFromNode(
  node: Node,
  flags: IssueFlagMap,
  ancestorsRecorded: boolean
): string[] {
  if (node.flag) {
    if (!ancestorsRecorded || !flags[node.flag]) return [];
    const childLabels = node.children.flatMap((child) =>
      labelsFromNode(child, flags, true)
    );
    if (childLabels.length === 0) return [bullet(node.path)];
    return childLabels;
  }
  if (!ancestorsRecorded) return [];
  return node.children.flatMap((child) => labelsFromNode(child, flags, true));
}

function labelsFromFlags(flags: IssueFlagMap): string[] {
  return catalog.flatMap((node) => labelsFromNode(node, flags, true));
}

function labels(selected: IssuePath[]): string[] {
  return labelsFromFlags(flagsFromPaths(selected));
}

export const Issue = {
  flagsFromPaths,
  selectedPaths,
  labels,
};
