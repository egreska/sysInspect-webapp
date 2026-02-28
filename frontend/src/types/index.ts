export interface User {
  userId: string;
  email: string;
}

export interface Customer {
  id: string;
  name: string;
  contactName?: string;
  phone?: string;
  address?: string;
  city?: string;
  state?: string;
  zipCode?: string;
  site?: string;
  createdDate?: string;
}

export interface Inspection {
  id: string;
  date?: string;
  inspectorName?: string;
  customerId?: string;
  customer?: Customer;
  items?: InspectionItem[];
  createdDate?: string;
}

export interface InspectionItem {
  id: string;
  location: string;
  bayNumber?: string;
  importance: 'Critical' | 'Repair' | 'Monitor';
  comments?: string;
  sequenceNumber: number;
  photoData?: string | null;
  photoUrl?: string | null;
  
  // Upright damage
  upright: boolean;
  uprightFrontDamage?: boolean;
  uprightFrontTwisted?: boolean;
  uprightRearDamage?: boolean;
  uprightRearTwisted?: boolean;
  uprightAlignmentOutOfAlignment?: boolean;
  uprightAlignmentOutOfVerticalPlumb?: boolean;
  
  // Beam damage
  beam: boolean;
  beamFrontDamage?: boolean;
  beamFrontBowed?: boolean;
  beamRearDamage?: boolean;
  beamRearBowed?: boolean;
  
  // Bracing damage
  bracingDiagonal: boolean;
  bracingHorizontal: boolean;
  bracingDamage?: boolean;
  
  // Base plate damage
  basePlate: boolean;
  basePlateDamaged?: boolean;
  basePlateTwisted?: boolean;
  basePlateFloorDamaged?: boolean;
  
  // Anchor damage
  anchors: boolean;
  anchorsDamaged?: boolean;
  anchorsMissing?: boolean;
  anchorsTorqued?: boolean;
  
  // Wire deck damage
  wireDeck: boolean;
  wireDeckDamaged?: boolean;
  wireDeckMissing?: boolean;
  wireDeckOutOfPosition?: boolean;
  
  // Post protector damage
  postProtector: boolean;
  postProtectorDamaged?: boolean;
  postProtectorMissing?: boolean;
  postProtectorRepairRequired?: boolean;
  
  // Aisle guarding damage
  aisleGuarding: boolean;
  aisleGuardingDamaged?: boolean;
  aisleGuardingMissing?: boolean;
  aisleGuardingRepairRequired?: boolean;
}
