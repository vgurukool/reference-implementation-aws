#!/bin/bash
set -e
REGION="us-east-2"
CLUSTER_NAME="cnoe-ref-impl"
echo "▶️  Waking cluster $CLUSTER_NAME (scaling worker nodes to 2)..."
NODEGROUP=$(aws eks list-nodegroups --cluster-name $CLUSTER_NAME --region $REGION --query "nodegroups[0]" --output text)
if [ -n "$NODEGROUP" ] && [ "$NODEGROUP" != "None" ]; then
    aws eks update-nodegroup-config \
        --cluster-name $CLUSTER_NAME \
        --nodegroup-name $NODEGROUP \
        --scaling-config minSize=1,desiredSize=2,maxSize=4 \
        --region $REGION
    echo "✅ Nodegroup $NODEGROUP scaling to 2 nodes. Cluster will be ready in ~2 minutes."
else
    echo "⚠️ No nodegroup found for $CLUSTER_NAME."
fi
