private struct Row<T> {
	var lhs: T?
	var rhs: T?
}

public struct IndexDiff {
	public var addedIndexes: [Int]
	public var removedIndexes: [Int]
	public var updatedIndexes: [Int]
	public var movedIndexes: [ChangeDescriptor<Int>]
	
	public init<T>(_ context: DiffContext<T>) {
		let oldItems = context.oldItems
		let newItems = context.newItems
		let newItemsContainItem = context.newItemsContainItem
		let oldItemsContainItem = context.oldItemsContainItem
		let newItemWithSameIDAsItem = context.newItemWithSameIDAsItem
		let isSameInstanceComparator = context.isSameInstanceComparator
		let isEqualComparator = context.isEqualComparator
		
		var rows = Array<Row<T>>()
		
		var newIndex = 0
		var oldIndex = 0
		var rowIndex = 0
		
		var matchToOld = true
		var shouldSwitch = false
		
		while true {
			if newIndex >= newItems.count && oldIndex >= oldItems.count {
				break
			}
			rows.append(Row<T>(lhs: nil, rhs: nil))
			
			let oldItem: T? = (oldItems.count > oldIndex) ? oldItems[oldIndex] : nil
			let newItem: T? = (newItems.count > newIndex) ? newItems[newIndex] : nil

			if let oldItem = oldItem, let newItem = newItem {
				let lhsMatchExistsOnBothSides = newItemsContainItem(oldItem)
				let rhsMatchExistsOnBothSides = oldItemsContainItem(newItem)

				switch (lhsMatchExistsOnBothSides, rhsMatchExistsOnBothSides) {
				case (false, true):
					shouldSwitch = true
					if matchToOld {
						rows[rowIndex].lhs = oldItem
						oldIndex += 1
					}
					else {
						rows[rowIndex].rhs = newItem
						newIndex += 1
					}
				case (true, false):
					shouldSwitch = true
					if matchToOld {
						rows[rowIndex].rhs = newItem
						newIndex += 1
					}
					else {
						rows[rowIndex].lhs = oldItem
						oldIndex += 1
					}
				case (true, true):
					if shouldSwitch {
						shouldSwitch = false
						matchToOld = !matchToOld
					}
					rows[rowIndex].lhs = oldItem
					rows[rowIndex].rhs = newItem
					newIndex += 1
					oldIndex += 1
				case (false, false): assertionFailure() // we shouldn't get here
				}
			}
			else {
				if let oldItem = oldItem {
					rows[rowIndex].lhs = oldItem
					oldIndex += 1
				}
				else if let newItem = newItem {
					rows[rowIndex].rhs = newItem
					newIndex += 1
				}
			}
			
			rowIndex += 1
		}

		let oldRowsWithoutNils = rows.filter { $0.lhs != nil }
		let newRowsWithoutNils = rows.filter { $0.rhs != nil }
		
		var movedIndexes: [ChangeDescriptor<Int>] = []
		var addedIndexes: [Int] = []
		var removedIndexes: [Int] = []
		var updatedIndexes: [Int] = []
		
		var insertionShift = 0
		var removalShift = 0

		for (index, row) in rows.enumerated() {
			switch (row.lhs, row.rhs) {

			case (_?, nil):
				removalShift += 1
				removedIndexes.append(index - insertionShift)
				
			case (nil, _?):
				insertionShift += 1
				addedIndexes.append(index - removalShift)
				
			case (let lhs?, _?):
				guard let oldIndex = oldRowsWithoutNils.index(where: { isSameInstanceComparator(lhs, $0.lhs!) }) else { continue }
				guard let newIndex = newRowsWithoutNils.index(where: { isSameInstanceComparator(lhs, $0.rhs!) }) else { continue }
				if newIndex != (oldIndex - removalShift + insertionShift) {
					movedIndexes.append(ChangeDescriptor(from: index, to: newIndex))
				}
				
				guard let newItem = newItemWithSameIDAsItem(lhs) else { continue }
				if !isEqualComparator(newItem, lhs) {
					updatedIndexes.append(index)
				}
				
			case (nil, nil): break
			}
		}
		
		self.removedIndexes = removedIndexes
		self.addedIndexes = addedIndexes
		self.updatedIndexes = updatedIndexes
		self.movedIndexes = movedIndexes
	}
}
